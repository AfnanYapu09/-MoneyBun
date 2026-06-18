import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/icon_chip.dart';
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final int amountCents;
  final TxnType type;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (sign, color) = switch (type) {
      TxnType.income => ('+', AppColors.green),
      TxnType.expense => ('−', AppColors.ink),
      TxnType.transfer => ('', AppColors.ink3),
    };
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          IconChip(icon: icon, size: 42, radius: 14, iconSize: 20),
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
