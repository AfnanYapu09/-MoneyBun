import 'package:flutter/widgets.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

/// Derived display fields for a transaction row.
class TxnDisplay {
  const TxnDisplay(this.icon, this.title, this.sub, {this.color});
  final IconData icon;
  final String title;
  final String sub;

  /// The category's colour, so the row icon matches the look in
  /// category management. Null for transfers / uncategorised rows, which keep
  /// the default terra tint.
  final Color? color;
}

TxnDisplay txnDisplay(
  TransactionRow t, {
  required Map<String, CategoryRow> categories,
  required Map<String, AccountRow> accounts,
  required String locale,
  bool withTime = true,
  bool withDate = false,
}) {
  final category = t.categoryId == null ? null : categories[t.categoryId];
  final categoryColor =
      category == null ? null : AppColors.forHex(category.colorHex);
  final when = AppDate.fromMillis(t.occurredAt);
  final time = AppDate.formatTime(when, locale: locale);
  // For lists that span more than one day (e.g. search results), lead the
  // subtitle with the day + month so each hit is dated.
  final date =
      withDate ? '${AppDate.formatDayShort(when, locale: locale)} · ' : '';

  switch (t.type) {
    case TxnType.transfer:
      final from = accounts[t.accountId]?.name ?? 'บัญชี';
      final to = accounts[t.toAccountId]?.name ?? 'บัญชี';
      return TxnDisplay(AppIcons.arrowLeftRight, 'ย้ายเงิน', '$date$from → $to',
          color: AppColors.amber);
    case TxnType.income:
      final title = (t.note != null && t.note!.isNotEmpty)
          ? t.note!
          : (category?.name ?? 'รายรับ');
      final sub = category != null
          ? '$date${category.name}${withTime ? ' · $time' : ''}'
          : '$dateรายรับ${withTime ? ' · $time' : ''}';
      final icon = category != null
          ? CategoryIcons.forKey(category.iconKey)
          : AppIcons.banknote;
      return TxnDisplay(icon, title, sub, color: categoryColor);
    case TxnType.expense:
      if (t.categoryId == null) {
        return TxnDisplay(AppIcons.receiptText, 'รายการใหม่จากสลิป',
            '$dateยังไม่จัดหมวด · $time');
      }
      final title = (t.note != null && t.note!.isNotEmpty)
          ? t.note!
          : (category?.name ?? 'รายการ');
      final sub =
          '$date${category?.name ?? 'อื่นๆ'}${withTime ? ' · $time' : ''}';
      return TxnDisplay(CategoryIcons.forKey(category?.iconKey), title, sub,
          color: categoryColor);
  }
}
