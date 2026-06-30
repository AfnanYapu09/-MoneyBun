import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Draws a dashed rounded-rectangle border (the design's `2px dashed terra`
/// affordance used by the home "scanned" + circle, the budget "add" button and
/// the manage-categories "add" button). Paints only the stroke; lay content
/// inside via [child].
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = AppColors.terra,
    this.strokeWidth = 2,
    this.radius = 14,
    this.dash = 5,
    this.gap = 4,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        radius: radius,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap;
}
