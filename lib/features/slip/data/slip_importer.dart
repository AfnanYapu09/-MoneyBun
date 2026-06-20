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
}

/// Reads slip images straight from the phone gallery and turns each genuine
/// slip into an entry — fully automatic, no album picking.
///
/// Thai banking apps save slips into their own gallery album (K PLUS, Krungthai
/// NEXT, TrueMoney, …), so a scan: (1) imports **every** image in albums whose
/// name matches a known bank/e-wallet, and (2) also checks the most recent
/// [_scanCap] photos of the whole gallery, importing those that look like slips
/// (QR or an amount) — to catch slips saved as screenshots/downloads. Dedups by
/// gallery asset id. Android-only.
class SlipImporter {
  SlipImporter({
    required SlipPipeline pipeline,
    required SlipRepository slips,
    required TransactionRepository transactions,
    required Future<Set<String>> Function() importedAssetIds,
    required Future<Set<String>> Function() disabledScanIds,
  })  : _pipeline = pipeline,
        _slips = slips,
        _txns = transactions,
        _importedAssetIds = importedAssetIds,
        _disabledScanIds = disabledScanIds;

  final SlipPipeline _pipeline;
  final SlipRepository _slips;
  final TransactionRepository _txns;
  final Future<Set<String>> Function() _importedAssetIds;

  /// Scan-catalog ids the user turned off (their albums are skipped this scan).
  final Future<Set<String>> Function() _disabledScanIds;

  /// Cap on how many recent "all photos" the fallback pass inspects.
  static const _scanCap = 150;

  /// Cap on images read per bank album (protects a long slip history).
  static const _albumCap = 300;

  /// Only read photos from the past this-many days, so a scan never trawls a
  /// whole month of old photos (slow). Already-imported photos are skipped by
  /// asset id, so this window alone keeps re-scans cheap.
  static const _scanWindowDays = 7;

  /// The earliest photo-creation time a scan reads: always the last
  /// [_scanWindowDays] days. Asset-id dedup (not a moving watermark) prevents
  /// re-imports, so a just-saved slip is always found once the gallery indexes
  /// it. Pure + static so it can be unit-tested.
  static DateTime scanCutoff(DateTime now) =>
      now.subtract(const Duration(days: _scanWindowDays));

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
    // Krungsri
    'kma', 'krungsri', 'กรุงศรี', 'uchoose',
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
    // other banks / e-wallets
    'cimb', 'kkp', 'kiatnakin', 'tisco', 'lh bank', 'lhbank', 'icbc', 'citi',
    'line bk', 'linebk', 'line pay', 'linepay', 'rabbit line',
    'dolfin', 'shopeepay', 'shopee pay', 'airpay', 'dime',
    // generic slip hints
    'prompt', 'slip', 'สลิป', 'ธนาคาร', 'โอนเงิน',
  ];

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

  /// Whether [name] is a bank/e-wallet slip album. Public + static so it can be
  /// unit-tested.
  static bool isSlipAlbumName(String name) {
    final n = name.toLowerCase().trim();
    if (_isMakeKbank(n)) return true;
    return _slipAlbumKeywords.any(n.contains);
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

  /// Open the system app-settings page so the user can grant photo access
  /// after a previous denial (where the prompt no longer re-appears).
  Future<void> openSettings() => PhotoManager.openSetting();

  /// Scan bank albums + recent photos for slips. Dedups by gallery asset id, so
  /// an already-imported photo is never imported twice. Returns a [ScanResult].
  Future<ScanResult> scanNew() async {
    final scanStart = DateTime.now();
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      if (paths.isEmpty) return const ScanResult();
      final already = await _importedAssetIds();
      // Only look at the past week; asset-id dedup (not a moving watermark)
      // skips photos already imported, so a just-saved slip is always found
      // once indexed, while re-scans stay cheap.
      final cutoff = scanCutoff(scanStart);
      bool inWindow(AssetEntity a) => a.createDateTime.isAfter(cutoff);
      // Banks the user turned off in the accounts sheet — skip their albums.
      final disabled = await _disabledScanIds();

      final acc = _ScanAcc();

      // 1) Bank/e-wallet albums: import slips from the window (they are all
      //    slips). Already-imported ones are skipped cheaply via [already].
      for (final album in paths) {
        if (album.isAll || !_isSlipAlbum(album.name)) continue;
        final scanId = albumScanId(album.name);
        if (scanId != null && disabled.contains(scanId)) continue;
        acc.matchedAlbums++;
        final count = await album.assetCountAsync;
        final end = count < _albumCap ? count : _albumCap;
        final assets = await album.getAssetListRange(start: 0, end: end);
        acc.albumCount += assets.length;
        final fresh = assets.where(inWindow).toList();
        await _ingest(fresh, already, acc, requireSlipLook: false);
      }

      // 2) Fallback: recent photos of the whole gallery that look like slips
      //    (screenshots / downloaded slips not in a bank album). Only those
      //    created within the window are inspected.
      final all = paths.firstWhere(
        (p) => p.isAll,
        orElse: () => paths.first,
      );
      final total = await all.assetCountAsync;
      final end = total < _scanCap ? total : _scanCap;
      final recent = await all.getAssetListRange(start: 0, end: end);
      acc.albumCount += recent.length;
      final fresh = recent.where(inWindow).toList();
      await _ingest(fresh, already, acc, requireSlipLook: true);

      return ScanResult(
        albumCount: acc.albumCount,
        matchedAlbums: acc.matchedAlbums,
        inspected: acc.inspected,
        imported: acc.imported,
        errors: acc.errors,
      );
    } finally {
      // Release the reusable QR controller + ML Kit recognizer once per scan.
      await _pipeline.dispose();
    }
  }

  Future<void> _ingest(
    List<AssetEntity> assets,
    Set<String> already,
    _ScanAcc acc, {
    required bool requireSlipLook,
  }) async {
    for (final asset in assets) {
      if (already.contains(asset.id)) continue;
      try {
        final file = await asset.file;
        if (file == null) continue;
        acc.inspected++;
        final parsed = (await _pipeline.process(file.path))
            .copyWith(imagePath: file.path, assetId: asset.id);
        if (requireSlipLook && !_looksLikeSlip(parsed)) continue;
        await _persist(parsed, asset.createDateTime);
        already.add(asset.id); // avoid a 2nd import via the fallback pass
        acc.imported++;
      } catch (_) {
        // One unreadable photo shouldn't abort the whole scan.
        acc.errors++;
      }
    }
  }

  /// A photo is treated as a slip if it carries a Thai slip-verify QR, or OCR
  /// found a money amount (`\d+.\d{2}`). Used for the recent-photos fallback —
  /// bank-album images are imported unconditionally.
  bool _looksLikeSlip(ParsedSlip p) =>
      p.qrPayload != null || p.amountCents != null;

  /// occurredAt comes from the slip itself (OCR); if unreadable, fall back to
  /// when the photo was saved — never the scan time — so entries land on the
  /// day of the slip.
  Future<void> _persist(ParsedSlip parsed, DateTime fallbackDate) async {
    final slipId = await _slips.save(parsed);
    // A slip now yields only an amount, so every import is recorded as an
    // expense; the user can change the type per-transaction when needed.
    await _txns.save(
      type: TxnType.expense,
      amountCents: parsed.amountCents ?? 0,
      occurredAt: parsed.occurredAt ?? fallbackDate,
      slipId: slipId,
    );
  }
}

/// Mutable running totals for a single scan.
class _ScanAcc {
  int albumCount = 0;
  int matchedAlbums = 0;
  int inspected = 0;
  int imported = 0;
  int errors = 0;
}
