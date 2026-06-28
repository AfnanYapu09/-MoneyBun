import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Renders a tiny pixel-art sprite from a [grid] of equal-length strings, in the
/// same crisp, non-antialiased style as the Bun mascot (`BunAvatar`).
///
/// Each character is one pixel:
///  - `.` or ` ` → transparent
///  - `#` → the main [color]
///  - `o` → a darker shade of [color] (outlines / shadow / depth)
///  - `*` → a lighter shade of [color] (highlights / glass / screens)
///
/// Using shades derived from one [color] keeps every icon themeable to its
/// category colour while still looking hand-crafted, like the mascot.
class PixelIcon extends StatelessWidget {
  const PixelIcon({
    super.key,
    required this.grid,
    required this.color,
    this.size = 24,
  });

  final List<String> grid;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PixelPainter(
          grid,
          color,
          Color.lerp(color, const Color(0xFF000000), 0.30)!,
          Color.lerp(color, const Color(0xFFFFFFFF), 0.62)!,
        ),
      ),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.grid, this.main, this.dark, this.light);

  final List<String> grid;
  final Color main;
  final Color dark;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    var cols = 0;
    for (final row in grid) {
      if (row.length > cols) cols = row.length;
    }
    if (cols == 0) return;
    final cell = size.width / cols;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == '.' || ch == ' ') continue;
        paint.color = switch (ch) {
          'o' => dark,
          '*' => light,
          _ => main,
        };
        // +0.5 overlap avoids hairline seams between cells (as in BunAvatar).
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelPainter old) =>
      old.grid != grid ||
      old.main != main ||
      old.dark != dark ||
      old.light != light;
}

/// A rounded-square tinted tile holding a [PixelIcon] — the pixel-art
/// counterpart of `IconChip`. Used wherever categories are shown (rows, grids,
/// stats, budgets).
class PixelIconChip extends StatelessWidget {
  const PixelIconChip({
    super.key,
    required this.grid,
    required this.color,
    this.size = 42,
    this.radius = 14,
    this.pixelSize = 26,
    this.background = AppColors.terraWash,
    this.circle = false,
  });

  final List<String> grid;
  final Color color;
  final double size;
  final double radius;
  final double pixelSize;
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
      child: PixelIcon(grid: grid, color: color, size: pixelSize),
    );
  }
}
