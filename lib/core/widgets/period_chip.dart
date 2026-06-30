import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_icons.dart';

/// Shared time-filter pill: ‹ label › where the centre opens the period picker
/// and the chevrons step to the previous / next period. Replaces [MonthChip] on
/// the screens that share the month/week filter.
class PeriodChip extends StatelessWidget {
  const PeriodChip({
    super.key,
    required this.label,
    this.onTapLabel,
    this.onPrev,
    this.onNext,
  });

  final String label;
  final VoidCallback? onTapLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: Tokens.pill,
          border: Tokens.hairline(context.palette.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chevron(icon: AppIcons.chevronLeft, onTap: onPrev),
            InkWell(
              borderRadius: Tokens.pill,
              onTap: onTapLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  style: AppTypography.heading(
                    size: 14,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            _Chevron(icon: AppIcons.chevronRight, onTap: onNext),
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: context.palette.ink3),
      ),
    );
  }
}
