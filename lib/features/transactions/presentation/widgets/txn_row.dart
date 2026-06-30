import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/icon_chip.dart';
import '../../../../core/widgets/pixel_icon.dart';
import '../../../../domain/enums/enums.dart';

/// A single transaction list row: tinted icon + title/sub + signed amount.
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.amountCents,
    required this.type,
    this.iconColor,
    this.iconKey,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final int amountCents;
  final TxnType type;

  /// The category colour for the leading icon (matches category management);
  /// null falls back to the default terra tint.
  final Color? iconColor;

  /// The category's pixel-art icon key, when category-backed. Renders the
  /// full-colour glyph; otherwise [icon] is used.
  final String? iconKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (sign, color) = switch (type) {
      TxnType.income => ('+', context.palette.greenFg),
      TxnType.expense => ('−', context.palette.ink),
      TxnType.transfer => ('', context.palette.amberFg),
    };
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (type == TxnType.transfer)
            PixelChip(
              maskKey: 'transfer',
              background: context.palette.amberWash,
              foreground: context.palette.amberFg,
              size: 42,
              radius: 14,
            )
          else if (hasPixelGlyph(iconKey))
            CategoryGlyph(
              iconKey: iconKey,
              color: iconColor ?? context.palette.terraWash,
              size: 42,
              radius: 14,
            )
          else
            IconChip(
              icon: icon,
              size: 42,
              radius: 14,
              iconSize: 20,
              background: iconColor ?? context.palette.terraWash,
              foreground:
                  iconColor == null ? context.palette.terraFg : Colors.white,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading(
                    size: 15,
                    weight: FontWeight.w500,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 12.5,
                    color: context.palette.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${Money.compact(amountCents.abs())}',
            style: AppTypography.heading(
              size: 15,
              weight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
