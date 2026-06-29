import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_icons.dart';
import 'app_toggle.dart';
import 'icon_chip.dart';
import 'pixel_icon.dart';

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
    this.iconKey,
    this.value,
    this.trailing,
    this.toggleValue,
    this.onToggle,
    this.onTap,
    this.showChevron = true,
    this.danger = false,
  });

  final IconData icon;

  /// When this resolves to a pixel-art glyph, the leading chip renders the
  /// pixel icon instead of [icon] (e.g. the notification bell).
  final String? iconKey;
  final String label;
  final String? value;
  final Widget? trailing;

  /// When set, renders the design's custom [AppToggle] as the trailing widget.
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;

  final VoidCallback? onTap;
  final bool showChevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.ink;
    final Widget? trailingWidget = toggleValue != null
        ? AppToggle(value: toggleValue!, onChanged: onToggle)
        : trailing;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          if (hasPixelGlyph(iconKey))
            CategoryGlyph(
              iconKey: iconKey,
              color: AppColors.terraWash,
              size: 34,
              radius: 11,
            )
          else
            IconChip(
              icon: icon,
              size: 34,
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
          if (trailingWidget != null) trailingWidget,
          if (trailingWidget == null && onTap != null && showChevron) ...[
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
    this.secondary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  /// Optional second line below [label] (e.g. a currency code).
  final String? secondary;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.body(size: 15)),
                  if (secondary != null)
                    Text(secondary!,
                        style: AppTypography.body(
                            size: 12.5, color: AppColors.ink3)),
                ],
              ),
            ),
            selected
                ? Icon(AppIcons.check, size: 20, color: primary)
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
