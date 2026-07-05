import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../data/local/database.dart';
import '../theme/colors.dart';
import 'app_icons.dart';

/// Renders a slip's stored image (Android).
///
/// Primary source is the slip's local [SlipRow.imagePath]. That path is
/// device-local and intentionally not synced, so after a sign-out/in (which
/// wipes the local DB) a restored slip has no path anymore — but its synced
/// [SlipRow.assetId] still identifies the original photo in this device's
/// gallery. When the path is missing or its file no longer exists, the image
/// is re-resolved from the gallery by asset id, so previously recorded slips
/// stay viewable after a re-login instead of degrading to a placeholder.
class SlipImage extends StatefulWidget {
  const SlipImage({super.key, required this.slip, this.fit = BoxFit.cover});

  final SlipRow? slip;
  final BoxFit fit;

  @override
  State<SlipImage> createState() => _SlipImageState();
}

class _SlipImageState extends State<SlipImage> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _file = _resolve();
  }

  @override
  void didUpdateWidget(SlipImage old) {
    super.didUpdateWidget(old);
    if (old.slip?.id != widget.slip?.id ||
        old.slip?.imagePath != widget.slip?.imagePath) {
      _file = _resolve();
    }
  }

  Future<File?> _resolve() async {
    final slip = widget.slip;
    if (slip == null) return null;
    final path = slip.imagePath;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      // Checked inside the future, not in build, to keep file I/O off the
      // frame; a dead path (cache purged, app data cleared) falls through to
      // the gallery lookup below.
      if (await f.exists()) return f;
    }
    final assetId = slip.assetId;
    if (assetId == null || assetId.isEmpty) return null;
    try {
      final asset = await AssetEntity.fromId(assetId);
      return await asset?.file;
    } catch (_) {
      // No gallery permission / asset deleted / non-mobile platform — the
      // placeholder below is the graceful end state.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        final file = snap.data;
        if (file == null) return _placeholder(context);
        return Image.file(
          file,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _placeholder(context),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: context.palette.terraWash,
        alignment: Alignment.center,
        child: Icon(AppIcons.receiptText, color: context.palette.terraFg),
      );
}
