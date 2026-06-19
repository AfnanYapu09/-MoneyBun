import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/progress.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).languageCode;
    final month = ref.watch(selectedMonthProvider);
    final txns = ref.watch(monthTransactionsProvider).value ?? const [];
    final budgets = (ref.watch(budgetsProvider).value ?? const <BudgetRow>[])
        .where((b) => b.period == BudgetPeriod.monthly && b.categoryId != null)
        .toList();
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };

    final spentByCat = <String, int>{};
    for (final t in txns.where((t) => t.type == TxnType.expense)) {
      if (t.categoryId == null) continue;
      spentByCat.update(t.categoryId!, (v) => v + t.amountCents,
          ifAbsent: () => t.amountCents);
    }
    final totalBudget = budgets.fold<int>(0, (s, b) => s + b.amountCents);
    final totalSpent =
        budgets.fold<int>(0, (s, b) => s + (spentByCat[b.categoryId] ?? 0));
    final remaining = totalBudget - totalSpent;
    final daysLeft = AppDate.endOfMonth(month).day - DateTime.now().day;

    return SubScreenScaffold(
      title: 'งบประมาณ',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        children: [
          MonthChip(
            label: AppDate.formatMonth(month, locale: locale),
            onPrev: () => ref.read(selectedMonthProvider.notifier).previous(),
            onNext: () => ref.read(selectedMonthProvider.notifier).next(),
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
                Text('ใช้ไปแล้วจากงบรวม',
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.reverse.withValues(alpha: 0.82))),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    text: Money.compact(totalSpent),
                    style: AppTypography.heading(
                        size: 34,
                        weight: FontWeight.w600,
                        color: AppColors.reverse),
                    children: [
                      TextSpan(
                        text: ' / ${Money.compact(totalBudget)}',
                        style: AppTypography.heading(
                            size: 18,
                            weight: FontWeight.w500,
                            color: AppColors.reverse.withValues(alpha: 0.8)),
                      ),
                    ],
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
                  'เหลืออีก ${Money.compact(remaining)} · อีก ${daysLeft < 0 ? 0 : daysLeft} วันสิ้นเดือน',
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.reverse.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('งบรายหมวด',
              style: AppTypography.heading(size: 16, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          if (budgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('ยังไม่มีงบรายหมวด',
                  style: AppTypography.body(size: 14, color: AppColors.ink3)),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < budgets.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _BudgetBar(
                      category: categories[budgets[i].categoryId],
                      spent: spentByCat[budgets[i].categoryId] ?? 0,
                      limit: budgets[i].amountCents,
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
  });
  final CategoryRow? category;
  final int spent;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final pct = limit == 0 ? 0.0 : spent / limit;
    final over = pct > 1.0;
    final color = over
        ? AppColors.danger
        : (pct > 0.85 ? AppColors.terra : AppColors.green);
    return Row(
      children: [
        IconChip(
            icon: CategoryIcons.forKey(category?.iconKey),
            size: 42,
            radius: 13,
            iconSize: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(category?.name ?? 'อื่นๆ',
                      style: AppTypography.body(size: 14.5)),
                  RichText(
                    text: TextSpan(
                      text: Money.compact(spent),
                      style: AppTypography.heading(
                          size: 13,
                          weight: FontWeight.w500,
                          color: over ? AppColors.danger : AppColors.ink),
                      children: [
                        TextSpan(
                          text: ' / ${Money.compact(limit)}',
                          style: AppTypography.body(
                              size: 13, color: AppColors.ink3),
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
              Text('เพิ่มงบหมวดใหม่',
                  style: AppTypography.heading(
                      size: 16,
                      weight: FontWeight.w500,
                      color: AppColors.terra)),
            ],
          ),
        ),
      ),
    );
  }
}
