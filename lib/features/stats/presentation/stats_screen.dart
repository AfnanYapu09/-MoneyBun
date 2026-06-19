import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/progress.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const _palette = [
    AppColors.terra,
    AppColors.terraDeep,
    Color(0xFFD98C6F),
    AppColors.green,
    Color(0xFFCDBFB0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).languageCode;
    final month = ref.watch(selectedMonthProvider);
    final txns = ref.watch(monthTransactionsProvider).value ?? const [];
    final allTxns = ref.watch(allTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final budgetCount = (ref.watch(budgetsProvider).value ?? const <BudgetRow>[])
        .where((b) => b.categoryId != null)
        .length;

    final expenses = txns.where((t) => t.type == TxnType.expense);
    final total = expenses.fold<int>(0, (s, t) => s + t.amountCents);
    final byCategory = <String, int>{};
    for (final t in expenses) {
      final key = t.categoryId ?? 'sys_other';
      byCategory.update(key, (v) => v + t.amountCents,
          ifAbsent: () => t.amountCents);
    }
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Previous-month comparison badge.
    final prevMonth = AppDate.addMonths(month, -1);
    final prevStart = AppDate.toMillis(AppDate.startOfMonth(prevMonth));
    final prevEnd = AppDate.toMillis(AppDate.endOfMonth(prevMonth));
    final prevTotal = allTxns
        .where((t) =>
            t.type == TxnType.expense &&
            t.occurredAt >= prevStart &&
            t.occurredAt <= prevEnd)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final pctChange =
        prevTotal > 0 ? ((total - prevTotal) / prevTotal * 100).round() : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
          children: [
            StaggeredColumn(
              spacing: 18,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('สถิติ',
                        style: AppTypography.heading(
                            size: 22, weight: FontWeight.w600)),
                    if (pctChange != null)
                      StatusBadge(
                        icon: pctChange <= 0
                            ? AppIcons.trendingDown
                            : AppIcons.arrowUpRight,
                        background: pctChange <= 0
                            ? AppColors.greenTint
                            : AppColors.terraWash,
                        foreground: pctChange <= 0
                            ? AppColors.green
                            : AppColors.terra700,
                        label: pctChange <= 0
                            ? 'น้อยกว่าเดือนก่อน ${pctChange.abs()}%'
                            : 'มากกว่าเดือนก่อน $pctChange%',
                      ),
                  ],
                ),
                MonthChip(
                  label: AppDate.formatMonth(month, locale: locale),
                  onPrev: () =>
                      ref.read(selectedMonthProvider.notifier).previous(),
                  onNext: () => ref.read(selectedMonthProvider.notifier).next(),
                ),
                Text('เงินหมดไปกับอะไร',
                    style: AppTypography.heading(
                        size: 16, weight: FontWeight.w500)),
                _DonutCard(
                    ranked: ranked,
                    total: total,
                    palette: _palette,
                    categories: categories),
                Row(
                  children: [
                    Expanded(
                      child: _EntryButton(
                        icon: AppIcons.wallet,
                        title: 'งบประมาณ',
                        sub: budgetCount > 0
                            ? '$budgetCount หมวดที่ตั้งไว้'
                            : 'ตั้งงบรายหมวด',
                        onTap: () => context.push('/budget'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EntryButton(
                        icon: AppIcons.arrowLeftRight,
                        title: 'เปรียบเทียบ',
                        sub: 'รายรับ–รายจ่าย',
                        onTap: () => context.push('/comparison'),
                      ),
                    ),
                  ],
                ),
                Text('แยกตามหมวด',
                    style: AppTypography.heading(
                        size: 16, weight: FontWeight.w500)),
                if (ranked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('ยังไม่มีข้อมูล',
                        style: AppTypography.body(
                            size: 14, color: AppColors.ink3)),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < ranked.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _CategoryBar(
                            category: categories[ranked[i].key],
                            cents: ranked[i].value,
                            fraction: total == 0 ? 0 : ranked[i].value / total,
                            color: _palette[i % _palette.length],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.ranked,
    required this.total,
    required this.palette,
    required this.categories,
  });
  final List<MapEntry<String, int>> ranked;
  final int total;
  final List<Color> palette;
  final Map<String, CategoryRow> categories;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (var i = 0; i < ranked.length; i++)
        DonutSegment(ranked[i].value.toDouble(), palette[i % palette.length]),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(vertical: 22),
      alignment: Alignment.center,
      child: DonutChart(
        segments: segments.isEmpty
            ? [const DonutSegment(1, AppColors.paper2)]
            : segments,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ใช้จ่ายรวม',
                style: AppTypography.body(size: 12, color: AppColors.ink3)),
            Text(Money.compact(total),
                style:
                    AppTypography.heading(size: 22, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconChip(icon: icon, size: 38, radius: 12, iconSize: 20),
                const Icon(AppIcons.arrowRight,
                    size: 18, color: AppColors.ink3),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style:
                    AppTypography.heading(size: 15, weight: FontWeight.w500)),
            Text(sub,
                style: AppTypography.body(size: 12, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.cents,
    required this.fraction,
    required this.color,
  });
  final CategoryRow? category;
  final int cents;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconChip(
            icon: CategoryIcons.forKey(category?.iconKey),
            size: 40,
            radius: 13,
            iconSize: 19),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(category?.name ?? 'อื่นๆ',
                      style: AppTypography.body(size: 14)),
                  Text(Money.compact(cents),
                      style: AppTypography.heading(
                          size: 14, weight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 6),
              ProgressBar(value: fraction, color: color, height: 7),
            ],
          ),
        ),
      ],
    );
  }
}
