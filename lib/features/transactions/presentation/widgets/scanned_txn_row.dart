import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/dashed_border.dart';
import '../../../../core/widgets/pixel_icon.dart';
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
    this.onShowSlip,
  });

  final TransactionRow txn;
  final String time;
  final VoidCallback? onTap;
  final VoidCallback? onCategorize;

  /// View the source slip — used by the warning affordance shown when a slip
  /// imported with an unreadable (zero) amount.
  final VoidCallback? onShowSlip;

  @override
  Widget build(BuildContext context) {
    // A slip whose amount OCR failed (฿0): flag it so the user can open the
    // slip and fix or delete it, instead of the usual "categorise" affordance.
    final needsAmount =
        txn.slipId != null && txn.amountCents == 0 && onShowSlip != null;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (needsAmount)
            InkWell(
              onTap: onShowSlip,
              customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.palette.dangerWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: PixelMaskIcon('alert',
                    color: context.palette.dangerFg, size: 24),
              ),
            )
          else
            InkWell(
              onTap: onCategorize,
              customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: DashedBorder(
                radius: 14,
                strokeWidth: 2,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Icon(AppIcons.plus,
                        size: 20, color: context.palette.terraFg),
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
                Text(
                    needsAmount
                        ? 'อ่านยอดเงินไม่ได้ · แตะดูสลิป'
                        : 'ยังไม่จัดหมวด · $time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 12.5,
                        color: needsAmount
                            ? context.palette.dangerFg
                            : context.palette.ink3)),
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
