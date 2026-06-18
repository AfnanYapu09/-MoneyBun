import 'package:flutter/material.dart';

import '../../features/accounts/presentation/accounts_sheet.dart';
import '../../features/add_transaction/presentation/add_transaction_sheet.dart';
import '../../features/add_transaction/presentation/category_picker_sheet.dart';
import '../../features/categories/presentation/add_category_sheet.dart';
import '../../features/stats/presentation/budget_sheet.dart';
import '../../domain/enums/enums.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/app_icons.dart';
import '../widgets/primary_button.dart';

const _barrier = Color(0x61211C18); // rgba(33,28,24,.38)

/// Full-height Add/Edit transaction sheet.
Future<bool?> showAddTransactionSheet(BuildContext context, {String? editId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: _barrier,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: AddTransactionSheet(editId: editId),
    ),
  );
}

/// Category + tag picker. Returns the chosen category and tags.
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  List<String> initialTagIds = const [],
}) {
  return showModalBottomSheet<CategoryPick>(
    context: context,
    isScrollControlled: true,
    barrierColor: _barrier,
    backgroundColor: Colors.transparent,
    builder: (_) => CategoryPickerSheet(initialTagIds: initialTagIds),
  );
}

/// Accounts watched for slips.
Future<void> showAccountsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: _barrier,
    backgroundColor: Colors.transparent,
    builder: (_) => const AccountsSheet(),
  );
}

/// Set a per-category budget.
Future<bool?> showBudgetSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    barrierColor: _barrier,
    backgroundColor: Colors.transparent,
    builder: (_) => const BudgetSheet(),
  );
}

/// Create a new category.
Future<bool?> showAddCategorySheet(
  BuildContext context, {
  CategoryType type = CategoryType.expense,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    barrierColor: _barrier,
    backgroundColor: Colors.transparent,
    builder: (_) => AddCategorySheet(type: type),
  );
}

/// Centered logout confirmation dialog. Returns true if confirmed.
Future<bool> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: _barrier,
    builder: (c) => Dialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.dangerWash,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(AppIcons.logOut,
                  color: AppColors.danger, size: 26),
            ),
            const SizedBox(height: 16),
            Text('ออกจากระบบ?',
                style:
                    AppTypography.heading(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('ข้อมูลของคุณยังอยู่ในเครื่องนี้',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 14, color: AppColors.ink2)),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'ออกจากระบบ',
              color: AppColors.danger,
              onPressed: () => Navigator.pop(c, true),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'ยกเลิก',
              onPressed: () => Navigator.pop(c, false),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
