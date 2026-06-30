import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

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
  const BunAvatar({
    super.key,
    this.size = 64,
    this.variant = BunVariant.normal,
  });

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

/// The onboarding illustration: a large Bun standing beside a small dark
/// calculator whose screen reads `฿2,001` (mirrors `bun.jsx` `bunCalcSVG`).
/// Natural canvas is 230×156; [width] scales it.
class BunCalculator extends StatelessWidget {
  const BunCalculator({super.key, this.width = 230});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 156 / 230,
      child: CustomPaint(painter: _BunCalcPainter()),
    );
  }
}

class _BunCalcPainter extends CustomPainter {
  static const _calcBody = Color(0xFF2E2823);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 230;

    // Bun (pixel grid, crisp), offset (4,4), cell 9.
    final px = Paint()..isAntiAlias = false;
    final cell = 9.0 * s;
    const ox = 4.0, oy = 4.0;
    for (var y = 0; y < _BunPainter._grid.length; y++) {
      final row = _BunPainter._grid[y];
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == '.') continue;
        px.color = ch == 'K'
            ? AppColors.ink
            : (ch == 'N' ? AppColors.terraDeep : AppColors.terra);
        canvas.drawRect(
          Rect.fromLTWH(
            (ox * s) + x * cell,
            (oy * s) + y * cell,
            cell + 0.5,
            cell + 0.5,
          ),
          px,
        );
      }
    }

    // Calculator body + screen + keys (anti-aliased rounded rects).
    final aa = Paint()..isAntiAlias = true;
    final cx = 150.0 * s, cy = 54.0 * s, cw = 70.0 * s, ch = 96.0 * s;
    aa.color = _calcBody;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy, cw, ch),
        Radius.circular(13 * s),
      ),
      aa,
    );
    aa.color = AppColors.cream;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 8 * s, cy + 10 * s, cw - 16 * s, 20 * s),
        Radius.circular(5 * s),
      ),
      aa,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '฿2,001',
        style: AppTypography.heading(
          size: 12 * s,
          weight: FontWeight.w600,
          color: AppColors.terraDeep,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(cx + cw - 9 * s - tp.width, cy + 22 * s - tp.height / 2),
    );

    final xs = [cx + 9 * s, cx + 29 * s, cx + 49 * s];
    final ys = [cy + 40 * s, cy + 58 * s, cy + 76 * s];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        aa.color = (i == 2 && j == 2) ? AppColors.terra : AppColors.cream;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(xs[j], ys[i], 14 * s, 13 * s),
            Radius.circular(3 * s),
          ),
          aa,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BunCalcPainter old) => false;
}
