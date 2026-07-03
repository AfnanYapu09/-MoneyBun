import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/providers.dart';
import '../../features/accounts/presentation/accounts_sheet.dart';
import '../../features/add_transaction/presentation/add_transaction_sheet.dart';
import '../../features/add_transaction/presentation/category_picker_sheet.dart';
import '../../features/categories/presentation/add_category_sheet.dart';
import '../../features/recurring/presentation/recurring_rule_sheet.dart';
import '../../features/stats/presentation/budget_sheet.dart';
import '../../features/stats/presentation/period_picker_sheet.dart';
import '../../data/local/database.dart';
import '../../domain/enums/enums.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/app_icons.dart';
import '../widgets/primary_button.dart';

const _barrier = Color(0x61211C18); // rgba(33,28,24,.38)

/// A bottom-pinned form sheet, fixed at 90% of the screen.
class _FormSheetSize extends StatelessWidget {
  const _FormSheetSize({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.bottomCenter,
      heightFactor: 0.9,
      child: child,
    );
  }
}

/// Runs [show] while marking a sheet open in [openSheetsProvider], so the home
/// FAB hides for the sheet's whole lifetime (and reappears once it closes).
Future<T?> _tracked<T>(BuildContext context, Future<T?> Function() show) async {
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(openSheetsProvider.notifier);
  notifier.increment();
  try {
    return await show();
  } finally {
    notifier.decrement();
  }
}

/// Add/Edit transaction sheet — sizes to its content (see [FullSheetScaffold]).
Future<bool?> showAddTransactionSheet(BuildContext context, {String? editId}) {
  return _tracked(
    context,
    () => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: _barrier,
      backgroundColor: context.palette.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => AddTransactionSheet(editId: editId),
    ),
  );
}

/// Category + tag picker. Returns the chosen category and tags. Pass [slip] to
/// show a "ดูสลิป" button and [onTransfer] to show a "ย้ายเงิน" button.
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  List<String> initialTagIds = const [],
  SlipRow? slip,
  VoidCallback? onTransfer,
}) {
  return _tracked(
    context,
    () => showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(
        initialTagIds: initialTagIds,
        slip: slip,
        onTransfer: onTransfer,
      ),
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

/// Create a recurring rule (auto-creates a transaction on a schedule). [type]
/// (income vs. expense) is inherited from the caller — the sheet has no picker
/// of its own — and defaults to expense when opened standalone (e.g. Settings).
Future<bool?> showRecurringRuleSheet(
  BuildContext context, {
  TxnType type = TxnType.expense,
}) {
  return _tracked(
    context,
    () => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => RecurringRuleSheet(type: type),
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
      useSafeArea: true,
      barrierColor: _barrier,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormSheetSize(child: AddCategorySheet(type: type)),
    ),
  );
}

/// Centered logout confirmation dialog. Returns true if confirmed.
Future<bool> confirmLogout(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: _barrier,
    builder: (c) => Dialog(
      backgroundColor: context.palette.bg,
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
                color: context.palette.dangerWash,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                AppIcons.logOut,
                color: context.palette.dangerFg,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.logoutTitle,
              style: AppTypography.heading(size: 19, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.logoutBody,
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 14, color: context.palette.ink2),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: l10n.signOut,
              color: AppColors.danger,
              onPressed: () => Navigator.pop(c, true),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: l10n.cancel,
              onPressed: () => Navigator.pop(c, false),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
