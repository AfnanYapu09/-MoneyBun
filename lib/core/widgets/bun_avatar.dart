import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Colour variant for the Bun mascot.
enum BunVariant {
  /// Terracotta body on light surfaces (default).
  normal,

  /// Cream body for use on a terracotta background.
  reverse,
}

/// "น้องบัน" (Bun) — the pixel mascot, drawn with a [CustomPainter] from the
/// design's 14×16 grid so it stays crisp at any size. `X`=body, `K`=eye,
/// `N`=nose/cheek shadow. See `design_files/bun.jsx` (`BUN_MAP`).
class BunAvatar extends StatelessWidget {
  const BunAvatar(
      {super.key, this.size = 64, this.variant = BunVariant.normal});

  /// Target width in logical pixels. Height is `size * 16/14`.
  final double size;
  final BunVariant variant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 16 / 14,
      child: CustomPaint(painter: _BunPainter(variant)),
    );
  }
}

class _BunPainter extends CustomPainter {
  _BunPainter(this.variant);

  final BunVariant variant;

  // 14 columns. Rabbit ears on top, square eyes, four stub legs.
  static const List<String> _grid = [
    '...XX....XX...',
    '...XX....XX...',
    '...XX.XX.XX...',
    '..XXXXXXXXXX..',
    '.XXXXXXXXXXXX.',
    'XXXXXXXXXXXXXX',
    'XXXKKXXXXKKXXX',
    'XXXKKXXXXKKXXX',
    'XXXXXXXXXXXXXX',
    'XXXXXXNNXXXXXX',
    'XXXXXXXXXXXXXX',
    '.XXXXXXXXXXXX.',
    '.XXXXXXXXXXXX.',
    '.XX.XX..XX.XX.',
    '.XX.XX..XX.XX.',
  ];

  Color get _body =>
      variant == BunVariant.reverse ? AppColors.reverse : AppColors.terra;
  Color get _eye =>
      variant == BunVariant.reverse ? AppColors.terraDeep : AppColors.ink;
  Color get _nose => AppColors.terraDeep;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 14;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < _grid.length; y++) {
      final row = _grid[y];
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == '.') continue;
        paint.color = ch == 'K' ? _eye : (ch == 'N' ? _nose : _body);
        // +0.5 overlap avoids hairline seams between cells.
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BunPainter old) => old.variant != variant;
}
