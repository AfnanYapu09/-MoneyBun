import 'package:photo_manager/photo_manager.dart';

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
    this.scannedAtMs = 0,
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

  /// The instant this scan started (ms since epoch) — persisted as the next
  /// scan's incremental watermark.
  final int scannedAtMs;
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
    required Future<int?> Function() lastSlipReadAt,
  })  : _pipeline = pipeline,
        _slips = slips,
        _txns = transactions,
        _importedAssetIds = importedAssetIds,
        _lastSlipReadAt = lastSlipReadAt;

  final SlipPipeline _pipeline;
  final SlipRepository _slips;
  final TransactionRepository _txns;
  final Future<Set<String>> Function() _importedAssetIds;
  final Future<int?> Function() _lastSlipReadAt;

  /// Cap on how many recent "all photos" the fallback pass inspects.
  static const _scanCap = 150;

  /// Cap on images read per bank album (protects a long slip history).
  static const _albumCap = 300;

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

  /// Whether [name] is a bank/e-wallet slip album. Public + static so it can be
  /// unit-tested.
  ///
  /// MAKE by KBank is special-cased: its gallery folder's real MediaStore
  /// bucket name is often just "MAKE" (the gallery only *labels* it
  /// "MAKE by KBank"), and a bare "make" keyword is unsafe (it would match
  /// "Makeup"). So MAKE is matched by exact/prefix rules instead.
  static bool isSlipAlbumName(String name) {
    final n = name.toLowerCase().trim();
    if (n == 'make' ||
        n.startsWith('make ') ||
        n.startsWith('make_') ||
        n.startsWith('make-') ||
        n.startsWith('makeby') ||
        n.contains('make by')) {
      return true;
    }
    return _slipAlbumKeywords.any(n.contains);
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
      if (paths.isEmpty) {
        return ScanResult(scannedAtMs: scanStart.millisecondsSinceEpoch);
      }
      final already = await _importedAssetIds();
      // Incremental watermark: only re-read photos newer than the last scan,
      // so a re-scan with no new photos does ~0 work instead of re-running the
      // pipeline over the same recent (non-slip) photos every time.
      final lastMs = await _lastSlipReadAt();
      final cutoff = (lastMs == null || lastMs == 0)
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastMs);

      final acc = _ScanAcc();

      // 1) Bank/e-wallet albums: import every image (they are all slips).
      //    Already-imported ones are skipped cheaply via [already].
      for (final album in paths) {
        if (album.isAll || !_isSlipAlbum(album.name)) continue;
        acc.matchedAlbums++;
        final count = await album.assetCountAsync;
        final end = count < _albumCap ? count : _albumCap;
        final assets = await album.getAssetListRange(start: 0, end: end);
        acc.albumCount += assets.length;
        await _ingest(assets, already, acc, requireSlipLook: false);
      }

      // 2) Fallback: recent photos of the whole gallery that look like slips
      //    (screenshots / downloaded slips not in a bank album). Only those
      //    created since the last scan are inspected.
      final all = paths.firstWhere(
        (p) => p.isAll,
        orElse: () => paths.first,
      );
      final total = await all.assetCountAsync;
      final end = total < _scanCap ? total : _scanCap;
      final recent = await all.getAssetListRange(start: 0, end: end);
      acc.albumCount += recent.length;
      final fresh = cutoff == null
          ? recent
          : recent.where((a) => a.createDateTime.isAfter(cutoff)).toList();
      await _ingest(fresh, already, acc, requireSlipLook: true);

      return ScanResult(
        albumCount: acc.albumCount,
        matchedAlbums: acc.matchedAlbums,
        inspected: acc.inspected,
        imported: acc.imported,
        errors: acc.errors,
        scannedAtMs: scanStart.millisecondsSinceEpoch,
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
    // A slip whose sender == receiver is money moved between the user's own
    // accounts — store it as a transfer so it never counts as spending.
    final isSelfTransfer = _namesMatch(parsed.senderName, parsed.receiverName);
    await _txns.save(
      type: isSelfTransfer ? TxnType.transfer : TxnType.expense,
      amountCents: parsed.amountCents ?? 0,
      occurredAt: parsed.occurredAt ?? fallbackDate,
      slipId: slipId,
    );
  }

  /// True when both names are present and equal once trimmed/case-folded.
  static bool _namesMatch(String? a, String? b) {
    final na = _normalizeName(a);
    return na.isNotEmpty && na == _normalizeName(b);
  }

  static String _normalizeName(String? s) =>
      (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Mutable running totals for a single scan.
class _ScanAcc {
  int albumCount = 0;
  int matchedAlbums = 0;
  int inspected = 0;
  int imported = 0;
  int errors = 0;
}
