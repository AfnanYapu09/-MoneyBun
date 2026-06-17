import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../theme/colors.dart';

/// Renders a slip's stored image — base64 (web/any) or a file path (mobile).
class SlipImage extends StatelessWidget {
  const SlipImage({super.key, required this.slip, this.fit = BoxFit.cover});

  final SlipRow? slip;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final s = slip;
    if (s != null && s.imageBase64 != null && s.imageBase64!.isNotEmpty) {
      return Image.memory(base64Decode(s.imageBase64!),
          fit: fit, errorBuilder: (_, __, ___) => _placeholder());
    }
    if (s != null && !kIsWeb && (s.imagePath ?? '').isNotEmpty) {
      return Image.file(File(s.imagePath!),
          fit: fit, errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: AppColors.gray100,
        alignment: Alignment.center,
        child: const Icon(Icons.receipt_long, color: AppColors.gray400),
      );
}
