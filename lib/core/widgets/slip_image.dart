import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../theme/colors.dart';
import 'app_icons.dart';

/// Renders a slip's stored image from its local file path (Android).
class SlipImage extends StatelessWidget {
  const SlipImage({super.key, required this.slip, this.fit = BoxFit.cover});

  final SlipRow? slip;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = slip?.imagePath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) => Container(
        color: context.palette.terraWash,
        alignment: Alignment.center,
        child: Icon(AppIcons.receiptText, color: context.palette.terraFg),
      );
}
