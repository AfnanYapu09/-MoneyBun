import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../data/repositories/slip_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/entities/parsed_slip.dart';
import 'slip_pipeline.dart';

/// Reads slip images straight from the phone gallery and turns each genuine
/// slip into an entry — fully automatic, no album picking.
///
/// A scan walks the "all photos" album newest-first, stops once it reaches
/// photos older than the previous scan, skips images already imported and
/// images that don't look like slips, and only ever inspects the most recent
/// [_scanCap] photos. Android-only.
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

  /// Cap on how many recent photos a single scan inspects — protects the very
  /// first scan on a phone with a huge gallery.
  static const _scanCap = 200;

  Future<bool> ensurePermission() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    // `hasAccess` covers Android 14's "limited"/partial selection too.
    return state.isAuth || state.hasAccess;
  }

  /// Open the system app-settings page so the user can grant photo access
  /// after a previous denial (where the prompt no longer re-appears).
  Future<void> openSettings() => PhotoManager.openSetting();

  /// Scan photos added since the last run for slips. Returns the count imported.
  ///
  /// On the very first run (no prior scan) it only looks at photos saved this
  /// month, so a fresh install reads the current month's slips rather than the
  /// whole gallery. After that it resumes from the last-scan high-water mark.
  Future<int> scanNew() async {
    final lastScan = await _readLastScan();
    final now = DateTime.now();
    // First run: floor at the 1st of this month. Otherwise resume where we left.
    final floor = lastScan.millisecondsSinceEpoch == 0
        ? DateTime(now.year, now.month)
        : lastScan;

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (paths.isEmpty) return 0;
    final all = paths.first;
    final total = await all.assetCountAsync;
    final end = total < _scanCap ? total : _scanCap;
    final assets = await all.getAssetListRange(start: 0, end: end);
    final already = await _importedAssetIds();

    var newest = floor;
    var count = 0;
    for (final asset in assets) {
      final created = asset.createDateTime;
      // Assets come newest-first; stop once we reach already-scanned dates.
      if (!created.isAfter(floor)) break;
      if (created.isAfter(newest)) newest = created;
      if (already.contains(asset.id)) continue;
      final file = await asset.file;
      if (file == null) continue;
      final parsed = (await _pipeline.process(file.path))
          .copyWith(imagePath: file.path, assetId: asset.id);
      if (!_looksLikeSlip(parsed)) continue;
      await _persist(parsed, created);
      count++;
    }
    if (newest.isAfter(lastScan)) await _writeLastScan(newest);
    return count;
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

  // ---- last-scan high-water mark (kept in the app documents dir) ----

  Future<File> _lastScanFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/last_slip_scan');
  }

  Future<DateTime> _readLastScan() async {
    try {
      final f = await _lastScanFile();
      if (!f.existsSync()) return DateTime.fromMillisecondsSinceEpoch(0);
      final ms = int.tryParse((await f.readAsString()).trim());
      return DateTime.fromMillisecondsSinceEpoch(ms ?? 0);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<void> _writeLastScan(DateTime t) async {
    try {
      final f = await _lastScanFile();
      await f.writeAsString('${t.millisecondsSinceEpoch}');
    } catch (_) {}
  }
}
