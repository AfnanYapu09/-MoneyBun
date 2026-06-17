import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../data/repositories/slip_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/entities/parsed_slip.dart';
import '../../../domain/enums/enums.dart';
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
/// - **Android**: read straight from a chosen gallery album (`photo_manager`),
///   run the full QR+OCR pipeline, and skip assets already imported.
/// - **Web / manual**: multi-pick via `image_picker`. On web there's no ML Kit,
///   so the image is just stored and the user fills amount + category at home.
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
  final ImagePicker _picker = ImagePicker();

  /// Manual multi-pick (web + mobile). Returns the number of slips imported.
  Future<int> importPicked() async {
    final files = await _picker.pickMultiImage();
    var count = 0;
    for (final f in files) {
      await _persist(await _parseXFile(f));
      count++;
    }
    return count;
  }

  Future<ParsedSlip> _parseXFile(XFile f) async {
    if (kIsWeb) {
      final bytes = await f.readAsBytes();
      return ParsedSlip(
        source: SlipSource.ocr,
        imageBase64: base64Encode(bytes),
      );
    }
    final parsed = await _pipeline.process(f.path);
    return parsed.copyWith(imagePath: f.path);
  }

  // ---- Android album auto-scan ----

  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  Future<List<SlipAlbum>> listAlbums() async {
    if (kIsWeb) return const [];
    final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    final albums = <SlipAlbum>[];
    for (final p in paths) {
      albums.add(SlipAlbum(p.id, p.name, await p.assetCountAsync));
    }
    return albums;
  }

  /// Scan all not-yet-imported images in [albumId]. Returns number imported.
  Future<int> importFromAlbum(String albumId, {int max = 200}) async {
    if (kIsWeb) return 0;
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
