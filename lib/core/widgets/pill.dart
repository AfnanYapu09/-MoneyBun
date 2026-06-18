import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_icons.dart';

/// Centered month selector pill: ‹ label › with prev/next chevrons.
class MonthChip extends StatelessWidget {
  const MonthChip({
    super.key,
    required this.label,
    this.onPrev,
    this.onNext,
  });

  final String label;
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
          border: Tokens.hairline(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chevron(icon: AppIcons.chevronLeft, onTap: onPrev),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(label,
                  style:
                      AppTypography.heading(size: 14, weight: FontWeight.w500)),
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
        child: Icon(icon, size: 18, color: AppColors.ink3),
      ),
    );
  }
}

/// A rounded pill chip (tags, quick amounts, filters).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surface,
        borderRadius: Tokens.pill,
        border: Border.all(
          color: selected ? scheme.primary : AppColors.line,
          width: 1.5,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: AppTypography.heading(
          size: 14,
          weight: FontWeight.w500,
          color: selected ? AppColors.reverse : AppColors.ink2,
        ),
        child: child,
      ),
    );
    if (onTap == null) return box;
    return InkWell(borderRadius: Tokens.pill, onTap: onTap, child: box);
  }
}

/// Small green-tint status badge, e.g. "↓ น้อยกว่าเดือนก่อน 12%".
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.background = AppColors.greenTint,
    this.foreground = AppColors.green,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: Tokens.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: AppTypography.heading(
                  size: 12.5, weight: FontWeight.w500, color: foreground)),
        ],
      ),
    );
  }
}
