import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../data/local/database.dart';
import '../../../../domain/enums/enums.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../txn_display.dart';
import 'scanned_txn_row.dart';
import 'txn_row.dart';

/// One day's worth of transactions: a date header with the day's net, then a
/// bordered card of rows. Uncategorised slip expenses render as a dashed-"+"
/// [ScannedTxnRow]; everything else uses [TxnRow]. Shared by the home recent
/// list and the all-transactions screen so the two stay identical.
class TxnDayGroup extends StatelessWidget {
  const TxnDayGroup({
    super.key,
    required this.day,
    required this.rows,
    required this.categories,
    required this.accounts,
    required this.locale,
    required this.onTapTxn,
    required this.onCategorize,
    this.onShowSlip,
    this.onDelete,
  });

  final DateTime day;
  final List<TransactionRow> rows;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final String locale;
  final void Function(String id) onTapTxn;
  final void Function(TransactionRow txn) onCategorize;

  /// View the source slip of a row (used by the zero-amount warning).
  final void Function(TransactionRow txn)? onShowSlip;

  /// Delete a row. When set, each row becomes swipe-to-delete: dragging it from
  /// right to left reveals a red delete action and, after a confirm dialog,
  /// removes the transaction. Null disables the gesture.
  final Future<void> Function(TransactionRow txn)? onDelete;

  static bool isUncategorized(TransactionRow t) =>
      t.type == TxnType.expense && t.categoryId == null;

  @override
  Widget build(BuildContext context) {
    final net = rows.fold<int>(
      0,
      (s, t) => switch (t.type) {
        TxnType.income => s + t.amountCents,
        TxnType.expense => s - t.amountCents,
        TxnType.transfer => s,
      },
    );
    final netStr =
        '${net > 0 ? '+' : net < 0 ? '−' : ''}${Money.compact(net.abs())}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppDate.relativeDayLabel(day, locale: locale),
                style: AppTypography.heading(size: 15, weight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                AppDate.formatWeekday(day, locale: locale),
                style: AppTypography.body(
                  size: 12.5,
                  color: context.palette.ink3,
                ),
              ),
              const Spacer(),
              Text(
                netStr,
                style: AppTypography.heading(
                  size: 13.5,
                  weight: FontWeight.w500,
                  color:
                      net > 0 ? context.palette.greenFg : context.palette.ink2,
                ),
              ),
            ],
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.palette.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildRow(context, rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, TransactionRow t) {
    final Widget row;
    if (isUncategorized(t)) {
      row = ScannedTxnRow(
        txn: t,
        time: AppDate.formatTime(
          AppDate.fromMillis(t.occurredAt),
          locale: locale,
        ),
        onTap: () => onTapTxn(t.id),
        onCategorize: () => onCategorize(t),
        onShowSlip: onShowSlip == null ? null : () => onShowSlip!(t),
      );
    } else {
      final d = txnDisplay(
        t,
        categories: categories,
        accounts: accounts,
        locale: locale,
        context: context,
      );
      row = TxnRow(
        icon: d.icon,
        title: d.title,
        sub: d.sub,
        iconColor: d.color,
        iconKey: d.iconKey,
        amountCents: t.amountCents,
        type: t.type,
        onTap: () => onTapTxn(t.id),
      );
    }
    if (onDelete == null) return row;
    return Dismissible(
      key: ValueKey('txn-${t.id}'),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(context),
      // Always returns false: the delete is performed here and the reactive
      // transaction list rebuilds without this row, so we never ask the
      // Dismissible to remove a widget that's still owned by the parent list
      // (which would trip the "dismissed widget still in the tree" assertion).
      confirmDismiss: (_) => _confirmDelete(context, t),
      child: row,
    );
  }

  /// Compact, iOS-style delete affordance revealed while swiping a row from
  /// right to left: a soft rounded pill (light red wash) holding a dark red
  /// trash icon — a small hint pinned to the right edge, not a full-bleed band.
  Widget _deleteBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      child: Container(
        width: 56,
        margin: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: context.palette.dangerWash,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Icon(
            AppIcons.trash2,
            size: 20,
            color: context.palette.dangerFg,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, TransactionRow t) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l10n.addtxnConfirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await onDelete!(t);
    return false;
  }
}
