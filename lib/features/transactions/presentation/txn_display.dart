import 'package:flutter/widgets.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/account_l10n.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/category_l10n.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

/// Derived display fields for a transaction row.
class TxnDisplay {
  const TxnDisplay(this.icon, this.title, this.sub, {this.color, this.iconKey});
  final IconData icon;
  final String title;
  final String sub;

  /// The category's colour, so the row icon matches the look in
  /// category management. Null for transfers / uncategorised rows, which keep
  /// the default terra tint.
  final Color? color;

  /// The category's icon key, when this row is category-backed — lets the row
  /// render the full-colour pixel-art glyph. Null (transfer / uncategorised /
  /// no-category) falls back to [icon].
  final String? iconKey;
}

TxnDisplay txnDisplay(
  TransactionRow t, {
  required Map<String, CategoryRow> categories,
  required Map<String, AccountRow> accounts,
  required String locale,
  bool withTime = true,
  bool withDate = false,
  BuildContext? context,
}) {
  final isThai = locale.startsWith('th');
  final category = t.categoryId == null ? null : categories[t.categoryId];
  final categoryColor =
      category == null ? null : AppColors.forHex(category.colorHex);
  final when = AppDate.fromMillis(t.occurredAt);
  final time = AppDate.formatTime(when, locale: locale);
  // For lists that span more than one day (e.g. search results), lead the
  // subtitle with the day + month so each hit is dated.
  final date =
      withDate ? '${AppDate.formatDayShort(when, locale: locale)} · ' : '';

  // Short fallback nouns. Date helpers and category names are already
  // bilingual, so we only branch the literals this function owns.
  final accountWord = isThai ? 'บัญชี' : 'Account';
  final incomeWord = isThai ? 'รายรับ' : 'Income';
  final otherWord = isThai ? 'อื่นๆ' : 'Other';

  switch (t.type) {
    case TxnType.transfer:
      final from = accounts[t.accountId]?.displayName(locale) ?? accountWord;
      final to = accounts[t.toAccountId]?.displayName(locale) ?? accountWord;
      final transferWord = isThai ? 'ย้ายเงิน' : 'Transfer';
      return TxnDisplay(AppIcons.arrowLeftRight, transferWord, '$date$from → $to',
          color: context?.palette.amberFg ?? AppColors.amber);
    case TxnType.income:
      final categoryName = category?.displayName(locale);
      final title = (t.note != null && t.note!.isNotEmpty)
          ? t.note!
          : (categoryName ?? incomeWord);
      final sub = categoryName != null
          ? '$date$categoryName${withTime ? ' · $time' : ''}'
          : '$date$incomeWord${withTime ? ' · $time' : ''}';
      final icon = category != null
          ? CategoryIcons.forKey(category.iconKey)
          : AppIcons.banknote;
      return TxnDisplay(icon, title, sub,
          color: categoryColor, iconKey: category?.iconKey);
    case TxnType.expense:
      if (t.categoryId == null) {
        final fromSlip = isThai ? 'รายการใหม่จากสลิป' : 'New item from slip';
        final uncategorized = isThai ? 'ยังไม่จัดหมวด' : 'Uncategorized';
        return TxnDisplay(AppIcons.receiptText, fromSlip,
            '$date$uncategorized · $time');
      }
      final categoryName = category?.displayName(locale);
      final itemWord = isThai ? 'รายการ' : 'Item';
      final title = (t.note != null && t.note!.isNotEmpty)
          ? t.note!
          : (categoryName ?? itemWord);
      final sub =
          '$date${categoryName ?? otherWord}${withTime ? ' · $time' : ''}';
      return TxnDisplay(CategoryIcons.forKey(category?.iconKey), title, sub,
          color: categoryColor, iconKey: category?.iconKey);
  }
}
