import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_icons.dart';
import 'icon_chip.dart';

/// Small uppercase-ish section label above a settings group.
class SettingSectionLabel extends StatelessWidget {
  const SettingSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text,
            style: AppTypography.heading(
                size: 13, weight: FontWeight.w500, color: AppColors.ink3)),
      );
}

/// A paper card grouping several [SettingRow]s with hairline dividers.
class SettingGroup extends StatelessWidget {
  const SettingGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: rows),
    );
  }
}

/// A single settings row: icon chip + label, with a trailing widget
/// (toggle / value+chevron / custom). Tappable when [onTap] is set.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.ink;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconChip(
            icon: icon,
            size: 36,
            radius: 11,
            iconSize: 18,
            background: danger ? AppColors.dangerWash : AppColors.terraWash,
            foreground: danger ? AppColors.danger : AppColors.terra700,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: AppTypography.body(size: 15, color: fg)),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(value!,
                  style: AppTypography.body(size: 14, color: AppColors.ink3)),
            ),
          if (trailing != null) trailing!,
          if (trailing == null && onTap != null && showChevron) ...[
            const SizedBox(width: 4),
            const Icon(AppIcons.chevronRight, size: 19, color: AppColors.ink3),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A selectable row with a leading radio/check (currency, theme, etc.).
class SelectRow extends StatelessWidget {
  const SelectRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(label, style: AppTypography.body(size: 15)),
            ),
            Icon(
              selected ? AppIcons.check : null,
              size: 20,
              color: selected ? primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
