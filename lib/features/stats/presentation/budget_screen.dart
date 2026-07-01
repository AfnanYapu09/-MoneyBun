import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/budget_math.dart';
import '../../../core/utils/category_l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/period_chip.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/progress.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final period = ref.watch(selectedPeriodProvider);
    final txns = ref.watch(periodTransactionsProvider).value ?? const [];
    final budgets = (ref.watch(budgetsProvider).value ?? const <BudgetRow>[])
        .where((b) => b.categoryId != null)
        .toList();
    // Each budget (weekly / monthly / yearly) is converted to the viewing
    // window so its target compares fairly against the period's spending.
    int target(BudgetRow b) => budgetForWindow(b.amountCents, b.period, period);
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };

    final spentByCat = <String, int>{};
    for (final t in txns.where((t) => t.type == TxnType.expense)) {
      if (t.categoryId == null) continue;
      spentByCat.update(
        t.categoryId!,
        (v) => v + t.amountCents,
        ifAbsent: () => t.amountCents,
      );
    }
    final totalBudget = budgets.fold<int>(0, (s, b) => s + target(b));
    final totalSpent = budgets.fold<int>(
      0,
      (s, b) => s + (spentByCat[b.categoryId] ?? 0),
    );
    final remaining = totalBudget - totalSpent;
    final daysLeft = period.daysRemaining;

    return SubScreenScaffold(
      title: l10n.statsBudget,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        children: [
          PeriodChip(
            label: period.label(locale),
            onTapLabel: () => showPeriodPickerSheet(context),
            onPrev: () => ref.read(selectedPeriodProvider.notifier).previous(),
            onNext: () => ref.read(selectedPeriodProvider.notifier).next(),
          ),
          const SizedBox(height: 18),
          // Summary card
          Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              color: AppColors.terra,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.statsSpentFromTotal,
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.reverse.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      text: Money.compact(totalSpent),
                      style: AppTypography.heading(
                        size: 34,
                        weight: FontWeight.w600,
                        color: AppColors.reverse,
                      ),
                      children: [
                        TextSpan(
                          text: ' / ${Money.compact(totalBudget)}',
                          style: AppTypography.heading(
                            size: 18,
                            weight: FontWeight.w500,
                            color: AppColors.reverse.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: totalBudget == 0
                        ? 0
                        : (totalSpent / totalBudget).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.reverse.withValues(alpha: 0.28),
                    valueColor: const AlwaysStoppedAnimation(AppColors.reverse),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.statsRemainingDays(
                    Money.compact(remaining),
                    daysLeft,
                    period.periodEndNoun(locale),
                  ),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.reverse.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.statsCategoryBudgets,
            style: AppTypography.heading(size: 16, weight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          if (budgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.statsNoCategoryBudgets,
                style: AppTypography.body(
                  size: 14,
                  color: context.palette.ink3,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.palette.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < budgets.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showBudgetSheet(context, budget: budgets[i]),
                      child: _BudgetBar(
                        category: categories[budgets[i].categoryId],
                        spent: spentByCat[budgets[i].categoryId] ?? 0,
                        limit: target(budgets[i]),
                        periodLabel: budgetPeriodLabel(
                          budgets[i].period,
                          locale,
                        ),
                        alert: budgets[i].alertEnabled,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          _DashedAddButton(onTap: () => showBudgetSheet(context)),
        ],
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.category,
    required this.spent,
    required this.limit,
    required this.periodLabel,
    required this.alert,
  });
  final CategoryRow? category;
  final int spent;
  final int limit;
  final String periodLabel;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final pct = limit == 0 ? 0.0 : spent / limit;
    final over = pct > 1.0;
    final color = over
        ? context.palette.dangerFg
        : (pct > 0.85 ? AppColors.terra : context.palette.greenFg);
    return Row(
      children: [
        if (category == null)
          IconChip(
            icon: CategoryIcons.forKey(null),
            size: 42,
            radius: 13,
            iconSize: 20,
          )
        else
          CategoryGlyph(
            iconKey: category!.iconKey,
            color: AppColors.forHex(category!.colorHex),
            size: 42,
            radius: 13,
            iconSize: 20,
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            category?.displayName(locale) ?? l10n.statsOther,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(size: 14.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            periodLabel,
                            style: AppTypography.body(
                              size: 10.5,
                              color: context.palette.ink3,
                            ),
                          ),
                        ),
                        if (alert && pct >= 0.8) ...[
                          const SizedBox(width: 6),
                          Icon(AppIcons.bellRing, size: 13, color: color),
                        ],
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: Money.compact(spent),
                      style: AppTypography.heading(
                        size: 13,
                        weight: FontWeight.w500,
                        color: over
                            ? context.palette.dangerFg
                            : context.palette.ink,
                      ),
                      children: [
                        TextSpan(
                          text: ' / ${Money.compact(limit)}',
                          style: AppTypography.body(
                            size: 13,
                            color: context.palette.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ProgressBar(value: pct.clamp(0.0, 1.0), color: color, height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: DashedBorder(
        radius: 16,
        strokeWidth: 1.5,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.plus, size: 20, color: AppColors.terra),
              const SizedBox(width: 8),
              Text(
                l10n.statsAddCategoryBudget,
                style: AppTypography.heading(
                  size: 16,
                  weight: FontWeight.w500,
                  color: AppColors.terra,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
