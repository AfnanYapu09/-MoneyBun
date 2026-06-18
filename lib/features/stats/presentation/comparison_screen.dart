import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/progress.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../domain/enums/enums.dart';

class _MonthAgg {
  _MonthAgg(this.month, this.income, this.expense);
  final DateTime month;
  final int income;
  final int expense;
  int get saved => income - expense;
}

class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).languageCode;
    final selected = ref.watch(selectedMonthProvider);
    final allTxns = ref.watch(allTransactionsProvider).value ?? const [];

    // Last 4 months ending at the selected month.
    final months = [
      for (var i = 3; i >= 0; i--) AppDate.addMonths(selected, -i)
    ];
    final aggs = months.map((m) {
      final start = AppDate.toMillis(AppDate.startOfMonth(m));
      final end = AppDate.toMillis(AppDate.endOfMonth(m));
      var inc = 0, exp = 0;
      for (final t in allTxns) {
        if (t.occurredAt < start || t.occurredAt > end) continue;
        if (t.type == TxnType.income) inc += t.amountCents;
        if (t.type == TxnType.expense) exp += t.amountCents;
      }
      return _MonthAgg(m, inc, exp);
    }).toList();

    final current = aggs.last;
    final avgSaved =
        (aggs.fold<int>(0, (s, a) => s + a.saved) / aggs.length).round();

    return SubScreenScaffold(
      title: 'เปรียบเทียบ',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: _HeroCard(
                  label: 'เก็บได้เดือนนี้',
                  value: Money.compact(current.saved),
                  background: AppColors.greenTint,
                  foreground: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroCard(
                  label: 'เฉลี่ย 4 เดือน',
                  value: Money.compact(avgSaved),
                  background: AppColors.paper,
                  foreground: AppColors.ink,
                  bordered: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart card
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('รายรับ vs รายจ่าย',
                        style: AppTypography.heading(
                            size: 15, weight: FontWeight.w500)),
                    Row(
                      children: const [
                        _Legend(color: AppColors.green, label: 'รายรับ'),
                        SizedBox(width: 12),
                        _Legend(color: AppColors.terra, label: 'รายจ่าย'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GroupedBarChart(
                  groups: [
                    for (final a in aggs)
                      BarGroupData(
                        label:
                            AppDate.formatMonthShort(a.month, locale: locale),
                        income: a.income / 100.0,
                        expense: a.expense / 100.0,
                        active: a.month.year == current.month.year &&
                            a.month.month == current.month.month,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('รายเดือน',
              style: AppTypography.heading(size: 16, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                for (var i = aggs.length - 1; i >= 0; i--) ...[
                  if (i < aggs.length - 1) const Divider(height: 1),
                  _MonthRow(
                    agg: aggs[i],
                    locale: locale,
                    active: i == aggs.length - 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
    this.bordered = false,
  });
  final String label;
  final String value;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: bordered ? Border.all(color: AppColors.line) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.body(
                  size: 13,
                  color: foreground == AppColors.green
                      ? AppColors.green
                      : AppColors.ink2)),
          const SizedBox(height: 2),
          Text(value,
              style: AppTypography.heading(
                  size: 22, weight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.body(size: 12, color: AppColors.ink2)),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow(
      {required this.agg, required this.locale, required this.active});
  final _MonthAgg agg;
  final String locale;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: active ? AppColors.terraWash : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(AppDate.formatMonthName(agg.month, locale: locale),
                style:
                    AppTypography.heading(size: 14.5, weight: FontWeight.w500)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${Money.compact(agg.income)}',
                  style: AppTypography.heading(
                      size: 12.5, color: AppColors.green)),
              Text('−${Money.compact(agg.expense)}',
                  style:
                      AppTypography.heading(size: 12.5, color: AppColors.ink2)),
            ],
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('เก็บได้',
                    style: AppTypography.body(size: 11, color: AppColors.ink3)),
                Text(Money.compact(agg.saved),
                    style: AppTypography.heading(
                        size: 14, weight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
