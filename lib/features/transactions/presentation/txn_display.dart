import 'package:flutter/widgets.dart';

import '../../../core/utils/app_date.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

/// Derived display fields for a transaction row.
class TxnDisplay {
  const TxnDisplay(this.icon, this.title, this.sub);
  final IconData icon;
  final String title;
  final String sub;
}

TxnDisplay txnDisplay(
  TransactionRow t, {
  required Map<String, CategoryRow> categories,
  required Map<String, AccountRow> accounts,
  required String locale,
  bool withTime = true,
}) {
  final category = t.categoryId == null ? null : categories[t.categoryId];
  final time =
      AppDate.formatTime(AppDate.fromMillis(t.occurredAt), locale: locale);

  switch (t.type) {
    case TxnType.transfer:
      final from = accounts[t.accountId]?.name ?? 'บัญชี';
      final to = accounts[t.toAccountId]?.name ?? 'บัญชี';
      return TxnDisplay(AppIcons.arrowLeftRight, 'ย้ายเงิน', '$from → $to');
    case TxnType.income:
      final title = (t.note != null && t.note!.isNotEmpty)
          ? t.note!
          : (category?.name ?? 'รายรับ');
      final sub = category != null
          ? '${category.name}${withTime ? ' · $time' : ''}'
          : 'รายรับ${withTime ? ' · $time' : ''}';
      final icon = category != null
          ? CategoryIcons.forKey(category.iconKey)
          : AppIcons.banknote;
      return TxnDisplay(icon, title, sub);
    case TxnType.expense:
      if (t.categoryId == null) {
        return TxnDisplay(
            AppIcons.receiptText, 'รายการใหม่จากสลิป', 'ยังไม่จัดหมวด · $time');
      }
      final title = (t.note != null && t.note!.isNotEmpty)
          ? t.note!
          : (category?.name ?? 'รายการ');
      final sub = '${category?.name ?? 'อื่นๆ'}${withTime ? ' · $time' : ''}';
      return TxnDisplay(CategoryIcons.forKey(category?.iconKey), title, sub);
  }
}
