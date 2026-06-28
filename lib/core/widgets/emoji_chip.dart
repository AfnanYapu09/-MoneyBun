import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A rounded-square tinted tile showing a category [emoji] — the emoji
/// counterpart of [IconChip]. Used wherever categories are displayed (rows,
/// grids, stats, budgets). The background is a soft wash so the full-colour
/// emoji stays legible (see `AppColors.softHex` / `AppColors.soft`).
class EmojiChip extends StatelessWidget {
  const EmojiChip({
    super.key,
    required this.emoji,
    this.size = 42,
    this.radius = 14,
    this.emojiSize = 20,
    this.background = AppColors.terraWash,
    this.circle = false,
  });

  final String emoji;
  final double size;
  final double radius;
  final double emojiSize;
  final Color background;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: emojiSize, height: 1.0),
      ),
    );
  }
}
