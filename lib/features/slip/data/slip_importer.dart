import 'package:photo_manager/photo_manager.dart';

import '../../../data/repositories/slip_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/entities/parsed_slip.dart';
import 'slip_pipeline.dart';

/// A gallery album the user can point the slip scanner at.
class SlipAlbum {
  const SlipAlbum(this.id, this.name, this.count);
  final String id;
  final String name;
  final int count;
}

/// Brings slip images into the app and turns each into an entry.
///
/// Reads straight from a chosen gallery album (`photo_manager`), runs the full
/// QR+OCR pipeline on each image, stores the image, and skips assets that were
/// already imported. Android-only.
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

  Future<List<SlipAlbum>> listAlbums() async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    final albums = <SlipAlbum>[];
    for (final p in paths) {
      albums.add(SlipAlbum(p.id, p.name, await p.assetCountAsync));
    }
    return albums;
  }

  /// Scan all not-yet-imported images in [albumId]. Returns number imported.
  Future<int> importFromAlbum(String albumId, {int max = 200}) async {
    final already = await _importedAssetIds();
    final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (paths.isEmpty) return 0;
    final album = paths.firstWhere(
      (p) => p.id == albumId,
      orElse: () => paths.first,
    );
    final total = await album.assetCountAsync;
    final assets =
        await album.getAssetListRange(start: 0, end: total < max ? total : max);

    var count = 0;
    for (final asset in assets) {
      if (already.contains(asset.id)) continue;
      final file = await asset.file;
      if (file == null) continue;
      final parsed = (await _pipeline.process(file.path)).copyWith(
        imagePath: file.path,
        assetId: asset.id,
      );
      await _persist(parsed);
      count++;
    }
    return count;
  }

  Future<void> _persist(ParsedSlip parsed) async {
    final slipId = await _slips.save(parsed);
    await _txns.save(
      amountCents: parsed.amountCents ?? 0,
      occurredAt: parsed.occurredAt ?? DateTime.now(),
      slipId: slipId,
    );
  }
}
