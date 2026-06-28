import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/category_pixel.dart';
import '../../../../core/widgets/icon_chip.dart';
import '../../../../core/widgets/pixel_icon.dart';
import '../../../../domain/enums/enums.dart';

/// A single transaction list row: tinted icon/sprite + title/sub + signed amount.
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

  /// The category colour for the leading chip (matches category management);
  /// null falls back to the default terra tint.
  final Color? iconColor;

  /// The category's stored icon key; when set, its pixel sprite is shown in
  /// place of [icon].
  final String? iconKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (sign, color) = switch (type) {
      TxnType.income => ('+', AppColors.green),
      TxnType.expense => ('−', AppColors.ink),
      TxnType.transfer => ('', AppColors.amber),
    };
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (iconKey != null)
            PixelIconChip(
              grid: CategoryPixel.forKey(iconKey),
              color: iconColor ?? AppColors.terra700,
              size: 42,
              radius: 14,
              pixelSize: 27,
              background: iconColor == null
                  ? AppColors.terraWash
                  : AppColors.soft(iconColor!),
            )
          else
            IconChip(
              icon: icon,
              size: 42,
              radius: 14,
              iconSize: 20,
              background: iconColor ?? AppColors.terraWash,
              foreground: iconColor == null ? AppColors.terra700 : Colors.white,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading(
                        size: 15, weight: FontWeight.w500)),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.body(size: 12.5, color: AppColors.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$sign${Money.compact(amountCents.abs())}',
              style: AppTypography.heading(
                  size: 15, weight: FontWeight.w500, color: color)),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
