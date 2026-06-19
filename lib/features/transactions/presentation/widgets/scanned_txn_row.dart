import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/dashed_border.dart';
import '../../../../data/local/database.dart';

/// Row for an uncategorised slip import ("รายการใหม่จากสลิป").
///
/// Shows the dashed "+" affordance both on the home recent list and the
/// all-transactions list. Tapping the row opens the transaction detail;
/// tapping the "+" jumps straight to the category picker.
class ScannedTxnRow extends StatelessWidget {
  const ScannedTxnRow({
    super.key,
    required this.txn,
    required this.time,
    this.onTap,
    this.onCategorize,
  });

  final TransactionRow txn;
  final String time;
  final VoidCallback? onTap;
  final VoidCallback? onCategorize;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: onCategorize,
            customBorder:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: const DashedBorder(
              radius: 14,
              strokeWidth: 2,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child:
                      Icon(AppIcons.plus, size: 20, color: AppColors.terra700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รายการใหม่จากสลิป',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading(
                        size: 15, weight: FontWeight.w500)),
                Text('ยังไม่จัดหมวด · $time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.body(size: 12.5, color: AppColors.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('−${Money.compact(txn.amountCents.abs())}',
              style: AppTypography.heading(size: 15, weight: FontWeight.w500)),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
