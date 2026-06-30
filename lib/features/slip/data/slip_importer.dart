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
/// NEXT, TrueMoney, …), so a scan imports **every** image in albums whose name
/// matches a known bank/e-wallet. Photos outside a bank album (screenshots /
/// downloads) are intentionally NOT read — for privacy and accuracy, only the
/// bank albums are scanned. Dedups by gallery asset id (and slip transRef).
/// Android-only.
class SlipImporter {
  SlipImporter({
    required SlipPipeline pipeline,
    required SlipRepository slips,
    required TransactionRepository transactions,
    required Future<Set<String>> Function() importedAssetIds,
    required Future<Set<String>> Function() importedSlipRefs,
    required Future<int?> Function() latestSlipPhotoTime,
    required Future<Set<String>> Function() disabledScanIds,
  })  : _pipeline = pipeline,
        _slips = slips,
        _txns = transactions,
        _importedAssetIds = importedAssetIds,
        _importedSlipRefs = importedSlipRefs,
        _latestSlipPhotoTime = latestSlipPhotoTime,
        _disabledScanIds = disabledScanIds;

  final SlipPipeline _pipeline;
  final SlipRepository _slips;
  final TransactionRepository _txns;
  final Future<Set<String>> Function() _importedAssetIds;

  /// Bank transaction references already imported. A second dedup key (besides
  /// the gallery asset id) so the same slip isn't re-imported after a cloud
  /// restore, where the asset id may be missing.
  final Future<Set<String>> Function() _importedSlipRefs;

  /// Source-photo time of the latest imported slip (epoch ms), or null when
  /// none yet. Used as the scan watermark: read only photos newer than this.
  final Future<int?> Function() _latestSlipPhotoTime;

  /// Scan-catalog ids the user turned off (their albums are skipped this scan).
  final Future<Set<String>> Function() _disabledScanIds;

  /// Cap on images read per bank album (protects a long slip history).
  static const _albumCap = 300;

  /// Bootstrap window: when no slip has ever been imported, a scan reads only
  /// the past this-many days so it never trawls the whole gallery. Once a slip
  /// exists, the watermark (latest imported slip's photo time) takes over.
  static const _scanWindowDays = 7;

  /// The bootstrap cutoff (used only before any slip exists): the last
  /// [_scanWindowDays] days. Once slips exist, [scanNew] uses the watermark
  /// instead. Pure + static so it can be unit-tested.
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

  /// Scan recognised bank/e-wallet albums for slips. Dedups by gallery asset id
  /// (and the slip's transRef), so an already-imported photo is never imported
  /// twice. Photos outside a bank album (screenshots / downloads) are NOT read.
  /// Returns a [ScanResult].
  Future<ScanResult> scanNew() async {
    final scanStart = DateTime.now();
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      if (paths.isEmpty) return const ScanResult();
      final already = await _importedAssetIds();
      final knownRefs = await _importedSlipRefs();
      // Watermark: once any slip has been imported, read only photos newer than
      // the latest one — so a scan continues *after* the last slip and never
      // re-reads older ones. The watermark is recomputed from the slips table
      // (whose photoTakenAt syncs), so it survives a sign-out or reinstall.
      // Before the first slip exists, bootstrap from the past week.
      final watermarkMs = await _latestSlipPhotoTime();
      final cutoff = watermarkMs != null
          ? DateTime.fromMillisecondsSinceEpoch(watermarkMs)
          : scanCutoff(scanStart);
      // Inclusive at the cutoff so a slip saved in the same second as the
      // watermark isn't missed; the already-imported one is skipped by the
      // asset-id / transRef dedup below.
      bool inWindow(AssetEntity a) => !a.createDateTime.isBefore(cutoff);
      // Banks the user turned off in the accounts sheet — skip their albums.
      final disabled = await _disabledScanIds();

      final acc = _ScanAcc();

      // Import slips from recognised bank/e-wallet albums (every image in such
      // an album is a slip). Already-imported ones are skipped via [already]
      // and the transRef dedup inside _ingest.
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
        await _ingest(fresh, already, knownRefs, acc);
      }

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
    Set<String> knownRefs,
    _ScanAcc acc,
  ) async {
    for (final asset in assets) {
      if (already.contains(asset.id)) continue;
      try {
        final file = await asset.file;
        if (file == null) continue;
        acc.inspected++;
        final parsed = (await _pipeline.process(file.path))
            .copyWith(imagePath: file.path, assetId: asset.id);
        // Skip if this exact slip (by bank transaction reference) was already
        // imported — guards against a re-import when the asset id differs
        // (e.g. after restoring data from the cloud).
        final ref = parsed.transRef;
        if (ref != null && ref.isNotEmpty && knownRefs.contains(ref)) {
          already.add(asset.id);
          continue;
        }
        await _persist(parsed, asset.createDateTime);
        // Avoid a 2nd import if the photo also appears in another matched album.
        already.add(asset.id);
        if (ref != null && ref.isNotEmpty) knownRefs.add(ref);
        acc.imported++;
      } catch (_) {
        // One unreadable photo shouldn't abort the whole scan.
        acc.errors++;
      }
    }
  }

  /// occurredAt comes from the slip itself (OCR); if unreadable, fall back to
  /// when the photo was saved — never the scan time — so entries land on the
  /// day of the slip.
  Future<void> _persist(ParsedSlip parsed, DateTime fallbackDate) async {
    // fallbackDate is the photo's gallery creation time — store it as the
    // slip's photoTakenAt so it can advance the scan watermark.
    final slipId = await _slips.save(parsed, photoTakenAt: fallbackDate);
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
