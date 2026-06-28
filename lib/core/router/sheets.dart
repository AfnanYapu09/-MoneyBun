import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/providers.dart';
import '../../features/accounts/presentation/accounts_sheet.dart';
import '../../features/add_transaction/presentation/add_transaction_sheet.dart';
import '../../features/add_transaction/presentation/category_picker_sheet.dart';
import '../../features/categories/presentation/add_category_sheet.dart';
import '../../features/stats/presentation/budget_sheet.dart';
import '../../features/stats/presentation/period_picker_sheet.dart';
import '../../data/local/database.dart';
import '../../domain/enums/enums.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/app_icons.dart';
import '../widgets/primary_button.dart';

const _barrier = Color(0x61211C18); // rgba(33,28,24,.38)

/// Runs [show] while marking a sheet open in [openSheetsProvider], so the home
/// FAB hides for the sheet's whole lifetime (and reappears once it closes).
Future<T?> _tracked<T>(
    BuildContext context, Future<T?> Function() show) async {
  final notifier = ProviderScope.containerOf(context, listen: false)
      .read(openSheetsProvider.notifier);
  notifier.state++;
  try {
    return await show();
  } finally {
    notifier.state--;
  }
}

/// Full-height Add/Edit transaction sheet.
Future<bool?> showAddTransactionSheet(BuildContext context, {String? editId}) {
  return _tracked(
    context,
    () => showModalBottomSheet<bool>(
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
    ),
  );
}

/// Category + tag picker. Returns the chosen category and tags.
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  List<String> initialTagIds = const [],
}) {
  return _tracked(
    context,
    () => showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(initialTagIds: initialTagIds),
    ),
  );
}

/// Accounts watched for slips.
Future<void> showAccountsSheet(BuildContext context) {
  return _tracked(
    context,
    () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => const AccountsSheet(),
    ),
  );
}

/// Month/week time-filter picker (shared by Home / Stats / Budget).
Future<void> showPeriodPickerSheet(BuildContext context) {
  return _tracked(
    context,
    () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => const PeriodPickerSheet(),
    ),
  );
}

/// Set a per-category budget, or edit [budget] when passed.
Future<bool?> showBudgetSheet(BuildContext context, {BudgetRow? budget}) {
  return _tracked(
    context,
    () => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetSheet(budget: budget),
    ),
  );
}

/// Create a new category.
Future<bool?> showAddCategorySheet(
  BuildContext context, {
  CategoryType type = CategoryType.expense,
}) {
  return _tracked(
    context,
    () => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCategorySheet(type: type),
    ),
  );
}

/// Centered logout confirmation dialog. Returns true if confirmed.
Future<bool> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: _barrier,
    builder: (c) => Dialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.dangerWash,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(AppIcons.logOut,
                  color: AppColors.danger, size: 28),
            ),
            const SizedBox(height: 12),
            Text('ออกจากระบบ?',
                style:
                    AppTypography.heading(size: 19, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('ข้อมูลของคุณถูกบันทึกไว้แล้ว เข้าสู่ระบบใหม่ได้ทุกเมื่อ',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 14, color: AppColors.ink2)),
            const SizedBox(height: 18),
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
