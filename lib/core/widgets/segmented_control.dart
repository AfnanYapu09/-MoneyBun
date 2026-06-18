import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// One segment of a [SegmentedControl].
class Segment<T> {
  const Segment(
      {required this.value, required this.label, this.icon, this.color});
  final T value;
  final String label;
  final IconData? icon;

  /// Optional active accent (e.g. green for รายรับ). Defaults to primary.
  final Color? color;
}

/// A paper-2-track segmented control. Active segment is a raised paper pill.
/// Set [iconOverLabel] for the icon-above-label layout (Add sheet tabs).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.iconOverLabel = false,
  });

  final List<Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool iconOverLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paper2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final s in segments) Expanded(child: _buildSegment(context, s)),
        ],
      ),
    );
  }

  Widget _buildSegment(BuildContext context, Segment<T> s) {
    final on = s.value == value;
    final accent = s.color ?? Theme.of(context).colorScheme.primary;
    final fg = on ? accent : AppColors.ink3;
    final label = Text(
      s.label,
      style: AppTypography.heading(
          size: iconOverLabel ? 12 : 13.5,
          weight: on ? FontWeight.w500 : FontWeight.w400,
          color: fg),
    );
    final content = iconOverLabel && s.icon != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, size: 18, color: fg),
              const SizedBox(height: 2),
              label,
            ],
          )
        : (s.icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s.icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  label,
                ],
              )
            : Center(child: label));
    return GestureDetector(
      onTap: () => onChanged(s.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(vertical: iconOverLabel ? 7 : 9),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: on ? AppColors.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: on ? Tokens.segmentShadow : null,
        ),
        child: content,
      ),
    );
  }
}
