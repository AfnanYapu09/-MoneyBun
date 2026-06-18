import 'package:photo_manager/photo_manager.dart';

import '../../../data/repositories/slip_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/entities/parsed_slip.dart';
import 'slip_pipeline.dart';

/// Outcome of a scan — also a diagnostic so we can see where it stops when no
/// slips are found.
class ScanResult {
  const ScanResult({
    this.albumCount = 0,
    this.inspected = 0,
    this.imported = 0,
    this.errors = 0,
  });

  /// Total images photo_manager sees in the "all photos" album.
  final int albumCount;

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
/// A scan walks the "all photos" album newest-first up to [_scanCap], skips
/// images already imported (by gallery asset id) and images that don't look
/// like slips, and imports the rest. Android-only.
class SlipImporter {
  SlipImporter({
    required SlipPipeline pipeline,
    required SlipRepository slips,
    required TransactionRepository transactions,
    required Future<Set<String>> Function() importedAssetIds,
  })  : _pipeline = pipeline,
        _slips = slips,
        _txns = transactions,
        _importedAssetIds = importedAssetIds;

  final SlipPipeline _pipeline;
  final SlipRepository _slips;
  final TransactionRepository _txns;
  final Future<Set<String>> Function() _importedAssetIds;

  /// Cap on how many recent photos a single scan inspects — protects a phone
  /// with a huge gallery.
  static const _scanCap = 200;

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

  /// Scan the most recent photos for slips. Dedups by gallery asset id, so an
  /// already-imported photo is never imported twice. Returns a [ScanResult]
  /// describing what it saw.
  Future<ScanResult> scanNew() async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (paths.isEmpty) return const ScanResult();
    final all = paths.first;
    final total = await all.assetCountAsync;
    final end = total < _scanCap ? total : _scanCap;
    final assets = await all.getAssetListRange(start: 0, end: end);
    final already = await _importedAssetIds();

    var inspected = 0;
    var imported = 0;
    var errors = 0;
    for (final asset in assets) {
      if (already.contains(asset.id)) continue;
      try {
        final file = await asset.file;
        if (file == null) continue;
        inspected++;
        final parsed = (await _pipeline.process(file.path))
            .copyWith(imagePath: file.path, assetId: asset.id);
        if (!_looksLikeSlip(parsed)) continue;
        await _persist(parsed, asset.createDateTime);
        imported++;
      } catch (_) {
        // One unreadable photo shouldn't abort the whole scan.
        errors++;
      }
    }
    return ScanResult(
      albumCount: total,
      inspected: inspected,
      imported: imported,
      errors: errors,
    );
  }

  /// A photo is treated as a slip if it carries a Thai slip-verify QR, or OCR
  /// found a money amount (`\d+.\d{2}`). Thai slips almost always show a
  /// 2-decimal amount the Latin OCR can read, while ordinary photos rarely do —
  /// the bank name is often Thai-only, so we can't rely on detecting it.
  bool _looksLikeSlip(ParsedSlip p) =>
      p.qrPayload != null || p.amountCents != null;

  /// occurredAt comes from the slip itself (OCR); if unreadable, fall back to
  /// when the photo was saved — never the scan time — so entries land on the
  /// day of the slip.
  Future<void> _persist(ParsedSlip parsed, DateTime fallbackDate) async {
    final slipId = await _slips.save(parsed);
    await _txns.save(
      amountCents: parsed.amountCents ?? 0,
      occurredAt: parsed.occurredAt ?? fallbackDate,
      slipId: slipId,
    );
  }
}
