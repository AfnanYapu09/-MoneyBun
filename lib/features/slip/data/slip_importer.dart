import 'package:photo_manager/photo_manager.dart';

import '../../../core/constants/bank_catalog.dart';
import '../../../data/repositories/slip_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/entities/parsed_slip.dart';
import '../../../domain/enums/enums.dart';
import 'slip_pipeline.dart';

/// Outcome of a scan — also a diagnostic so we can see where it stops when no
/// slips are found.
class ScanResult {
  const ScanResult({
    this.albumCount = 0,
    this.matchedAlbums = 0,
    this.inspected = 0,
    this.imported = 0,
    this.errors = 0,
    this.newestImportedAt,
    this.quotaReached = false,
  });

  /// Total candidate images considered (bank albums + recent fallback).
  final int albumCount;

  /// Number of bank/e-wallet albums recognised by name (K PLUS, Krungthai, …).
  final int matchedAlbums;

  /// Images we actually ran the read pipeline on this scan.
  final int inspected;

  /// New slips imported this scan.
  final int imported;

  /// Images whose read threw (decode / ML Kit failure) and were skipped.
  final int errors;

  /// The `occurredAt` (epoch ms) of the newest entry imported this scan, or
  /// null when nothing was imported. The Home screen uses it to snap the
  /// visible month onto the imports so they never land off-screen.
  final int? newestImportedAt;

  /// The scan hit the plan's monthly slip quota (Free 30 / Ultra 300) and
  /// stopped importing — it still visits every matched album to keep the
  /// read-up-to cursor accurate. The photos it skipped are NOT retroactively
  /// re-read: once credit is added (same-month top-up or an Ultra upgrade),
  /// the next scan starts from wherever the cursor is by then, not from the
  /// day the quota ran out — and a new calendar month reads only that month.
  final bool quotaReached;
}

/// Reads slip images straight from the phone gallery and turns each genuine
/// slip into an entry — fully automatic, no album picking.
///
/// Thai banking apps save slips into their own gallery album (K PLUS, Krungthai
/// NEXT, TrueMoney, …), so a scan imports **every** image in albums whose name
/// matches a known bank/e-wallet. Photos outside a bank album (screenshots /
/// downloads) are intentionally NOT read — for privacy and accuracy, only the
/// bank albums are scanned. Every scan is scoped to the current calendar month
/// (see [effectiveCutoff]) and dedups by gallery asset id (and slip transRef).
/// Android-only.
class SlipImporter {
  SlipImporter({
    required SlipPipeline pipeline,
    required SlipRepository slips,
    required TransactionRepository transactions,
    required Future<Set<String>> Function() importedAssetIds,
    required Future<Set<String>> Function() importedSlipRefs,
    required Future<bool> Function(String assetId) assetImported,
    required Future<bool> Function(String transRef) refImported,
    required Future<int?> Function() latestSlipPhotoTime,
    required Future<Set<String>> Function() disabledScanIds,
    required Future<int?> Function() scannedUpTo,
    required Future<void> Function(int ms) saveScannedUpTo,
    required Future<int> Function() remainingScanQuota,
    required Future<int> Function() backfillCutoffMs,
    Future<T> Function<T>(Future<T> Function() action)? runInTransaction,
  })  : _pipeline = pipeline,
        _slips = slips,
        _txns = transactions,
        _runInTransaction = runInTransaction,
        _importedAssetIds = importedAssetIds,
        _importedSlipRefs = importedSlipRefs,
        _assetImported = assetImported,
        _refImported = refImported,
        _latestSlipPhotoTime = latestSlipPhotoTime,
        _disabledScanIds = disabledScanIds,
        _scannedUpTo = scannedUpTo,
        _saveScannedUpTo = saveScannedUpTo,
        _remainingScanQuota = remainingScanQuota,
        _backfillCutoffMs = backfillCutoffMs;

  final SlipPipeline _pipeline;
  final SlipRepository _slips;
  final TransactionRepository _txns;

  /// Wraps the slip+transaction pair-write in a DB transaction (see
  /// [_persist]). Optional so unit tests can construct the importer without a
  /// database; falls back to running the action directly.
  final Future<T> Function<T>(Future<T> Function() action)? _runInTransaction;
  final Future<Set<String>> Function() _importedAssetIds;

  /// Bank transaction references already imported. A second dedup key (besides
  /// the gallery asset id) so the same slip isn't re-imported after a cloud
  /// restore, where the asset id may be missing.
  final Future<Set<String>> Function() _importedSlipRefs;

  /// Point lookups against the live DB for the just-before-write dedup
  /// re-check (a cloud pull can restore a slip mid-scan). Indexed single-row
  /// queries — unlike re-reading the whole table per image, which made a big
  /// backlog scan O(images × slips).
  final Future<bool> Function(String assetId) _assetImported;
  final Future<bool> Function(String transRef) _refImported;

  /// Source-photo time of the latest imported slip (epoch ms), or null when
  /// none yet. Used as the scan watermark: read only photos newer than this.
  final Future<int?> Function() _latestSlipPhotoTime;

  /// Scan-catalog ids the user turned off (their albums are skipped this scan).
  final Future<Set<String>> Function() _disabledScanIds;

  /// Photo time (epoch ms) the previous scan read up to, or null when never
  /// recorded. A device-local record of "read this far" so photos already
  /// looked at — including ones that produced no import — aren't read again.
  final Future<int?> Function() _scannedUpTo;

  /// Persist the read-up-to record after a scan.
  final Future<void> Function(int ms) _saveScannedUpTo;

  /// How many more slips the membership allows right now (period free
  /// allowance + credit balance; effectively unlimited on Ultra). The scan
  /// stops importing non-backfill photos at zero.
  final Future<int> Function() _remainingScanQuota;

  /// Photos taken before this local-midnight instant (epoch ms) import free —
  /// the signup-month backfill. 0 = no backfill (guest / unknown signup).
  final Future<int> Function() _backfillCutoffMs;

  /// Cap on images read per bank album. A backstop only — the month window
  /// below bounds real scans; the cap just keeps a pathological album (tens of
  /// thousands of images) from stalling a scan forever.
  static const _albumCap = 2000;

  /// Where a scan starts reading. Never before the current calendar month —
  /// slips are only ever read from the month the scan runs in ("July shows
  /// July") — and never before what was already read.
  ///
  /// The device's own cursor ([scannedUpToMs]) is authoritative when present:
  /// it encodes this device's own read-up-to point, including the deliberate
  /// holdback for photos that errored out (kept AHEAD of the cursor so a
  /// later scan retries them — quota-blocked photos get no such holdback, by
  /// design: see [_ingest]). The newest imported slip's photo time
  /// ([watermarkMs], rebuilt from synced data) is only the fallback for a
  /// device with no cursor yet (fresh install / restore) — taking the max of
  /// both here used to let another device's sync jump this device's cutoff
  /// past a backlog it had never actually scanned.
  ///
  /// Inclusive at the boundary; the asset-id / transRef dedup catches a photo
  /// saved the same instant. Pure + static for unit tests.
  static DateTime effectiveCutoff(
    DateTime now, {
    int? watermarkMs,
    int? scannedUpToMs,
  }) {
    var cutoff = DateTime(now.year, now.month);
    final ms = scannedUpToMs ?? watermarkMs;
    if (ms != null) {
      final t = DateTime.fromMillisecondsSinceEpoch(ms);
      if (t.isAfter(cutoff)) cutoff = t;
    }
    return cutoff;
  }

  /// Album-name fragments (lowercase) that Thai banking / e-wallet apps use for
  /// the folder they save slips into. Matched albums are imported in full.
  /// Avoid over-broad single words (e.g. bare "make" → matches "makeup") — use
  /// distinctive tokens instead.
  static const _slipAlbumKeywords = <String>[
    // Kasikorn
    'k plus', 'kplus', 'kasikorn', 'กสิกร', 'kbank', 'make by kbank',
    // Krungthai
    'krungthai', 'กรุงไทย',
    // SCB
    'scb', 'ไทยพาณิชย์',
    // Bangkok Bank
    'bualuang', 'bangkok bank', 'กรุงเทพ',
    // ttb / TMB
    'ttb', 'tmb',
    // Krungsri ('kma' is bounded-matched — see _boundedKeywords)
    'krungsri', 'กรุงศรี', 'uchoose',
    // TrueMoney
    'truemoney', 'true money', 'ทรูมันนี่', 'ทรูมัน',
    // GSB / ออมสิน
    'gsb', 'mymo', 'ออมสิน',
    // BAAC
    'baac', 'ธกส',
    // UOB
    'uob', 'tmrw',
    // GHB / อาคารสงเคราะห์
    'ghb', 'อาคารสงเคราะห์', 'ธอส',
    // เป๋าตัง / Paotang
    'paotang', 'pao tang', 'เป๋าตัง',
    // other banks / e-wallets ('citi'/'dime' are bounded-matched)
    'cimb', 'kkp', 'kiatnakin', 'tisco', 'lh bank', 'lhbank', 'icbc',
    'citibank',
    'line bk', 'linebk', 'line pay', 'linepay', 'rabbit line',
    'dolfin', 'shopeepay', 'shopee pay', 'airpay',
    // generic slip hints ('prompt' is bounded-matched)
    'promptpay', 'slip', 'สลิป', 'ธนาคาร', 'โอนเงิน',
  ];

  /// Short fragments that occur inside ordinary album names ("Bookmarks"
  /// contains "kma", "Cities" contains "citi", "Prompts" contains "prompt") —
  /// a false match imports the WHOLE album as expense entries and burns quota.
  /// These match only at word boundaries; longer spellings ("citibank",
  /// "promptpay") stay in the contains list above.
  static const _boundedKeywords = <String>['kma', 'citi', 'prompt', 'dime'];

  static bool _isAlnum(int c) =>
      (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x7A);

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  /// Whether [original] (CASE-PRESERVED) contains [kw] (lowercase) delimited,
  /// on the left, by a non-alphanumeric or the string start, and on the
  /// right, by a non-alphanumeric, a digit, or an upper-case letter.
  ///
  /// The right side's extra allowances catch real brand-prefixed folder
  /// names that concatenate straight into a suffix with no separator —
  /// "KMA2024" (digit boundary) and "DimeWallet"/"CitiMobile" (a camelCase
  /// boundary: matching against the ORIGINAL casing here, not a lowercased
  /// copy, is what makes the upper-case letter register as "not alnum" via
  /// [_isAlnum]'s lowercase-only letter range — that's the exact signal that
  /// distinguishes a real brand suffix from an ordinary word, since a plain
  /// English word like "Cities"/"Bookmarks"/"Sedimentary" never case-shifts
  /// right after the fragment). The left side stays strict (no such
  /// camelCase counter-example has come up), which is what still rejects
  /// "Bookmarks" and "Sedimentary" (the fragment sits mid-word on the left).
  static bool _containsBounded(String original, String kw) {
    final n = original.toLowerCase();
    var from = 0;
    while (true) {
      final i = n.indexOf(kw, from);
      if (i < 0) return false;
      final beforeOk = i == 0 || !_isAlnum(n.codeUnitAt(i - 1));
      final end = i + kw.length;
      final afterOk = end >= original.length ||
          _isDigit(original.codeUnitAt(end)) ||
          !_isAlnum(original.codeUnitAt(end));
      if (beforeOk && afterOk) return true;
      from = i + 1;
    }
  }

  bool _isSlipAlbum(String name) => isSlipAlbumName(name);

  /// MAKE by KBank is special-cased: its gallery folder's real MediaStore
  /// bucket name is often just "MAKE" (the gallery only *labels* it
  /// "MAKE by KBank"), and a bare "make" keyword is unsafe (it would match
  /// "Makeup"). So MAKE is matched by exact/prefix rules instead.
  static bool _isMakeKbank(String n) =>
      n == 'make' ||
      n.startsWith('make ') ||
      n.startsWith('make_') ||
      n.startsWith('make-') ||
      n.startsWith('makeby') ||
      n.contains('make by');

  /// Whether a photo taken at [photoMs] is free signup-month backfill: the
  /// cutoff is known (a signed-in account) and the photo predates it. A photo
  /// whose time the gallery doesn't know (epoch 0) is NEVER backfill —
  /// otherwise unknown-time photos would become an unlimited free loophole.
  /// Mirrors the countable-slip predicate in the database layer. Public +
  /// static so it can be unit-tested.
  static bool isBackfillPhoto(int photoMs, int backfillCutoffMs) =>
      backfillCutoffMs > 0 && photoMs != 0 && photoMs < backfillCutoffMs;

  /// Whether [name] is a bank/e-wallet slip album. Public + static so it can be
  /// unit-tested.
  static bool isSlipAlbumName(String name) {
    final trimmed = name.trim();
    final n = trimmed.toLowerCase();
    if (_isMakeKbank(n)) return true;
    if (_slipAlbumKeywords.any(n.contains)) return true;
    return _boundedKeywords.any((kw) => _containsBounded(trimmed, kw));
  }

  /// The scan-catalog id an album belongs to (a Kasikorn album → 'kbank', a
  /// MAKE album → 'make'), or null for a generic slip folder not tied to a
  /// togglable bank. Lets a scan skip a bank's album when it's turned off.
  static String? albumScanId(String name) {
    final n = name.toLowerCase().trim();
    if (_isMakeKbank(n)) return 'make';
    for (final bank in BankCatalog.all) {
      if (bank.id == 'make') continue; // handled above (safe MAKE detection)
      if (bank.albumKeywords.any(n.contains)) return bank.id;
    }
    return null;
  }

  /// Request photo access. Returns whether it was granted and whether it's the
  /// Android 14 "limited"/partial selection (where only chosen photos are seen).
  Future<({bool granted, bool limited})> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    return (
      granted: state.isAuth || state.hasAccess,
      limited: state == PermissionState.limited,
    );
  }

  /// Check photo access WITHOUT prompting — safe to call on every app entry
  /// and lifecycle resume to drive the permission banner.
  Future<({bool granted, bool limited})> checkPermission() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    return (
      granted: state.isAuth || state.hasAccess,
      limited: state == PermissionState.limited,
    );
  }

  /// Open the system app-settings page so the user can grant photo access
  /// after a previous denial (where the prompt no longer re-appears).
  Future<void> openSettings() => PhotoManager.openSetting();

  /// Re-open the Android 14 "select photos" sheet so the user can widen a
  /// limited/partial grant.
  Future<void> presentLimited() => PhotoManager.presentLimited();

  /// Scan recognised bank/e-wallet albums for slips. Dedups by gallery asset id
  /// (and the slip's transRef), so an already-imported photo is never imported
  /// twice. Photos outside a bank album (screenshots / downloads) are NOT read.
  /// Returns a [ScanResult].
  ///
  /// [isCancelled] is polled between photos; when it turns true the scan stops
  /// writing and returns what it has. The caller cancels when the signed-in
  /// user changes mid-scan — continuing would write the old gallery's entries
  /// into the just-wiped DB, from where they'd sync to the *next* account.
  Future<ScanResult> scanNew({bool Function()? isCancelled}) async {
    final scanStart = DateTime.now();
    bool cancelled() => isCancelled?.call() ?? false;
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        // Explicit newest-first order. Without it the platform query has NO
        // ORDER BY at all (just LIMIT/OFFSET), so which photos fall inside the
        // per-album cap is undefined — an album bigger than the cap could
        // silently drop its newest slips.
        filterOption: FilterOptionGroup(orders: const [OrderOption()]),
      );
      if (paths.isEmpty) return const ScanResult();
      final already = await _importedAssetIds();
      final knownRefs = await _importedSlipRefs();
      // Read only the current calendar month, and within it continue after
      // whatever was already read: the newest imported slip's photo time (from
      // the slips table, whose photoTakenAt syncs — survives a sign-out or
      // reinstall) and the previous scan's own read-up-to record.
      final cutoff = effectiveCutoff(
        scanStart,
        watermarkMs: await _latestSlipPhotoTime(),
        scannedUpToMs: await _scannedUpTo(),
      );
      // Inclusive at the cutoff so a slip saved in the same second as the
      // watermark isn't missed; the already-imported one is skipped by the
      // asset-id / transRef dedup below. A photo whose creation time the
      // gallery doesn't know (epoch 0) can never pass the cutoff — include it
      // anyway; after its first import the asset-id dedup skips it.
      bool inWindow(AssetEntity a) =>
          a.createDateTime.millisecondsSinceEpoch == 0 ||
          !a.createDateTime.isBefore(cutoff);
      // Banks the user turned off in the accounts sheet — skip their albums.
      final disabled = await _disabledScanIds();

      final acc = _ScanAcc()
        ..quotaRemaining = await _remainingScanQuota()
        ..backfillCutoffMs = await _backfillCutoffMs();

      // Import slips from recognised bank/e-wallet albums (every image in such
      // an album is a slip). Already-imported ones are skipped via [already]
      // and the transRef dedup inside _ingest.
      for (final album in paths) {
        // Keep visiting every matched album even after the quota is spent, so
        // every album's assets fold into newestSeenAt and the cursor reflects
        // the whole scan, not just whichever album happened to hit the limit
        // first. Only cancellation stops the album walk early.
        if (cancelled()) break;
        if (album.isAll || !_isSlipAlbum(album.name)) continue;
        final scanId = albumScanId(album.name);
        if (scanId != null && disabled.contains(scanId)) continue;
        acc.matchedAlbums++;
        final count = await album.assetCountAsync;
        final end = count < _albumCap ? count : _albumCap;
        final assets = await album.getAssetListRange(start: 0, end: end);
        acc.albumCount += assets.length;
        final fresh = assets.where(inWindow).toList();
        await _ingest(fresh, already, knownRefs, acc, cancelled);
      }

      // Record how far this scan read (the newest photo it considered, clamped
      // to the scan start so a future-dated photo can't jump the cursor), so
      // the next scan continues after it even when nothing was imported.
      // Errored photos stay ahead of the cursor and get retried: the record
      // stops just BEFORE the oldest failure instead of not advancing at all —
      // one permanently unreadable photo must not force every future scan to
      // re-OCR the whole month window. Quota-blocked photos do NOT get this
      // treatment (by design — see the comment in [_ingest]): the cursor
      // advances past them like anything else. Never advanced when cancelled
      // mid-scan.
      final seen = acc.newestSeenAt;
      if (!cancelled() && seen != null) {
        var upTo = seen;
        final startMs = scanStart.millisecondsSinceEpoch;
        if (upTo > startMs) upTo = startMs;
        final failedAt = acc.oldestErrorAt;
        if (failedAt != null && failedAt - 1 < upTo) upTo = failedAt - 1;
        await _saveScannedUpTo(upTo);
      }

      return ScanResult(
        albumCount: acc.albumCount,
        matchedAlbums: acc.matchedAlbums,
        inspected: acc.inspected,
        imported: acc.imported,
        errors: acc.errors,
        newestImportedAt: acc.newestImportedAt,
        quotaReached: acc.quotaReached,
      );
    } finally {
      // Release the reusable QR controller + ML Kit recognizer once per scan.
      await _pipeline.dispose();
    }
  }

  Future<void> _ingest(
    List<AssetEntity> assets,
    Set<String> already,
    Set<String> knownRefs,
    _ScanAcc acc,
    bool Function() cancelled,
  ) async {
    for (final asset in assets) {
      if (cancelled()) return;
      final seenMs = asset.createDateTime.millisecondsSinceEpoch;
      // The cursor advances past a photo the instant it's considered,
      // WHETHER OR NOT the quota blocks it — a quota-exhausted photo is
      // simply skipped, not held for a later retroactive catch-up. Once
      // credit is added, the NEXT scan starts from wherever the cursor is by
      // then (i.e. from today), not from the day the quota ran out. Product
      // decision: "1-20 used up the quota, 20-end of month reads nothing;
      // whichever day credit lands, reading starts from that day" — not a
      // month-long backfill of everything the quota blocked.
      if (acc.newestSeenAt == null || seenMs > acc.newestSeenAt!) {
        acc.newestSeenAt = seenMs;
      }
      final isBackfill = isBackfillPhoto(seenMs, acc.backfillCutoffMs);
      if (!already.contains(asset.id) &&
          !isBackfill &&
          acc.quotaUsed >= acc.quotaRemaining) {
        acc.quotaReached = true;
        continue;
      }
      if (already.contains(asset.id)) continue;
      try {
        final file = await asset.file;
        if (file == null) continue;
        acc.inspected++;
        final parsed = (await _pipeline.process(
          file.path,
        ))
            .copyWith(imagePath: file.path, assetId: asset.id);
        // Re-check the dedup keys against the live DB before persisting: a
        // cloud pull can land mid-scan (an app-resume sync) and restore this
        // very slip after the sets were snapshotted at scan start. Targeted
        // point lookups — re-reading the whole table per image made a big
        // backlog scan O(images × slips).
        if (await _assetImported(asset.id)) {
          already.add(asset.id);
          continue;
        }
        // Skip if this exact slip (by bank transaction reference) was already
        // imported — guards against a re-import when the asset id differs
        // (e.g. after restoring data from the cloud).
        final ref = parsed.transRef;
        if (ref != null &&
            ref.isNotEmpty &&
            (knownRefs.contains(ref) || await _refImported(ref))) {
          already.add(asset.id);
          continue;
        }
        // Checked again right before writing — the OCR above takes long enough
        // for a sign-out (and its DB wipe) to land in between.
        if (cancelled()) return;
        final occurredAt = await _persist(parsed, asset.createDateTime);
        // Avoid a 2nd import if the photo also appears in another matched album.
        already.add(asset.id);
        if (ref != null && ref.isNotEmpty) knownRefs.add(ref);
        acc.imported++;
        if (!isBackfill) acc.quotaUsed++;
        final ms = occurredAt.millisecondsSinceEpoch;
        if (acc.newestImportedAt == null || ms > acc.newestImportedAt!) {
          acc.newestImportedAt = ms;
        }
      } catch (_) {
        // One unreadable photo shouldn't abort the whole scan.
        acc.errors++;
        if (acc.oldestErrorAt == null || seenMs < acc.oldestErrorAt!) {
          acc.oldestErrorAt = seenMs;
        }
      }
    }
  }

  /// occurredAt comes from the slip itself (OCR); if unreadable, fall back to
  /// when the photo was saved — never the scan time — so entries land on the
  /// day of the slip.
  ///
  /// The two writes run in ONE database transaction: a crash between them
  /// would leave a slip row with no transaction — invisible to the user, yet
  /// counted by the quota accounting and dedup-blocked from ever retrying.
  Future<DateTime> _persist(ParsedSlip parsed, DateTime fallbackDate) {
    final runInTxn =
        _runInTransaction ?? <T>(Future<T> Function() action) => action();
    return runInTxn(() async {
      // fallbackDate is the photo's gallery creation time — store it as the
      // slip's photoTakenAt so it can advance the scan watermark.
      final slipId = await _slips.save(parsed, photoTakenAt: fallbackDate);
      final occurredAt = parsed.occurredAt ?? fallbackDate;
      // A slip now yields only an amount, so every import is recorded as an
      // expense; the user can change the type per-transaction when needed.
      await _txns.save(
        type: TxnType.expense,
        amountCents: parsed.amountCents ?? 0,
        occurredAt: occurredAt,
        slipId: slipId,
      );
      return occurredAt;
    });
  }
}

/// Mutable running totals for a single scan.
class _ScanAcc {
  int albumCount = 0;
  int matchedAlbums = 0;
  int inspected = 0;
  int imported = 0;
  int errors = 0;
  int? newestImportedAt;

  /// Imports the membership still allows this scan (fetched once at scan
  /// start).
  int quotaRemaining = 0;

  /// Quota actually consumed this scan — backfill imports don't count.
  int quotaUsed = 0;

  /// Free-backfill cutoff (photos older than this import free); 0 = none.
  int backfillCutoffMs = 0;

  /// The scan hit the membership limit and stopped early (shown to the user
  /// as "buy credit / upgrade to keep reading" — informational only; the
  /// photos it blocked are NOT retroactively re-read, by design: see
  /// [newestSeenAt]).
  bool quotaReached = false;

  /// Photo time (epoch ms) of the newest in-window asset this scan considered
  /// (imported or deduped) — persisted as the read-up-to record afterwards.
  int? newestSeenAt;

  /// Photo time (epoch ms) of the OLDEST asset whose read threw this scan.
  /// The read-up-to record stops just before it, so failed photos are retried
  /// while everything read successfully is never re-read.
  int? oldestErrorAt;
}
