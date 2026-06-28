import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// A rounded progress bar that grows from the left on first build.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.terra,
    this.track = AppColors.paper2,
    this.height = 8,
    this.animate = true,
  });

  final double value; // 0..1 (clamped)
  final Color color;
  final Color track;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: track,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : v, end: v),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => FractionallySizedBox(
              widthFactor: t,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One slice of a [DonutChart].
class DonutSegment {
  const DonutSegment(this.value, this.color);
  final double value;
  final Color color;
}

/// A donut/ring chart with a reveal animation and centered child.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 170,
    this.strokeWidth = 22,
    this.center,
  });

  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(
          painter: _DonutPainter(segments, strokeWidth, t),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.strokeWidth, this.t);
  final List<DonutSegment> segments;
  final double strokeWidth;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    var start = -math.pi / 2;
    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * math.pi * t;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = seg.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.t != t || old.segments != segments;
}

/// One month column for [GroupedBarChart].
class BarGroupData {
  const BarGroupData({
    required this.label,
    required this.income,
    required this.expense,
    this.active = false,
  });
  final String label;
  final double income;
  final double expense;
  final bool active;
}

/// Grouped income/expense monthly bars (Comparison screen).
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.groups,
    this.height = 168,
    this.incomeColor = AppColors.green,
    this.expenseColor = AppColors.terra,
    this.groupWidth,
  });

  final List<BarGroupData> groups;
  final double height;
  final Color incomeColor;
  final Color expenseColor;

  /// When set, each group is a fixed-width column and the chart scrolls
  /// horizontally — use it when there are too many groups to fit (e.g. 12
  /// months). When null, groups share the width via [Expanded].
  final double? groupWidth;

  @override
  Widget build(BuildContext context) {
    final max = groups.fold<double>(
        1, (m, g) => math.max(m, math.max(g.income, g.expense)));
    final bars = [for (final g in groups) _group(g, max)];
    if (groupWidth == null) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (final b in bars) Expanded(child: b)],
        ),
      );
    }
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final b in bars) SizedBox(width: groupWidth, child: b),
          ],
        ),
      ),
    );
  }

  Widget _group(BarGroupData g, double max) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(g.income / max, incomeColor, g.active),
              const SizedBox(width: 6),
              _bar(g.expense / max, expenseColor, g.active),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(g.label,
            style: AppTypography.heading(
                size: 12.5,
                weight: g.active ? FontWeight.w500 : FontWeight.w400,
                color: g.active ? AppColors.ink : AppColors.ink3)),
      ],
    );
  }

  Widget _bar(double frac, Color color, bool active) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: frac.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => FractionallySizedBox(
        heightFactor: t,
        child: Container(
          width: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: active ? 1 : 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
      ),
    );
  }
}
