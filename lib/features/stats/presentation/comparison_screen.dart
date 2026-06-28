import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/date_period.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/period_chip.dart';
import '../../../core/widgets/progress.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../domain/enums/enums.dart';

/// The spans shown on the comparison chart for the active mode, oldest → newest.
List<DatePeriod> _comparisonPeriods(DatePeriod p) {
  switch (p.mode) {
    case PeriodMode.month:
      // January through the selected month (so month 4 shows 4 bars, max 12).
      return [
        for (var m = 1; m <= p.anchor.month; m++)
          DatePeriod.month(DateTime(p.anchor.year, m)),
      ];
    case PeriodMode.year:
      return [
        for (var i = 4; i >= 0; i--)
          DatePeriod.year(AppDate.addYears(p.anchor, -i)),
      ];
    case PeriodMode.week:
      final monthEnd = AppDate.endOfMonth(p.monthAnchor);
      final weeks = <DatePeriod>[];
      var w = AppDate.startOfWeek(p.monthAnchor);
      while (!w.isAfter(monthEnd)) {
        weeks.add(DatePeriod.week(w));
        w = AppDate.addWeeks(w, 1);
      }
      return weeks;
  }
}

class _PeriodAgg {
  _PeriodAgg(this.period, this.income, this.expense);
  final DatePeriod period;
  final int income;
  final int expense;

  /// Savings is never negative — overspending shows as ฿0 saved, not a debt.
  int get saved {
    final s = income - expense;
    return s < 0 ? 0 : s;
  }
}

class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({super.key});

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  /// The bar the user tapped to inspect (null → show the selected period).
  DatePeriod? _focused;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final period = ref.watch(selectedPeriodProvider);
    final allTxns = ref.watch(allTransactionsProvider).value ?? const [];

    // The spans to compare, depending on the active mode:
    //   month → January through the selected month
    //   year  → the last 5 years ending at the selected year
    //   week  → every week of the selected month
    final aggs = _comparisonPeriods(period).map((pp) {
      var inc = 0, exp = 0;
      for (final t in allTxns) {
        if (t.occurredAt < pp.start || t.occurredAt > pp.end) continue;
        if (t.type == TxnType.income) inc += t.amountCents;
        if (t.type == TxnType.expense) exp += t.amountCents;
      }
      return _PeriodAgg(pp, inc, exp);
    }).toList();

    final current =
        aggs.firstWhere((a) => a.period == period, orElse: () => aggs.last);
    final focused =
        aggs.firstWhere((a) => a.period == _focused, orElse: () => current);
    final avgSaved =
        (aggs.fold<int>(0, (s, a) => s + a.saved) / aggs.length).round();
    final unitWord =
        period.isWeek ? 'สัปดาห์' : (period.isYear ? 'ปี' : 'เดือน');

    // Week bars/rows are numbered within the month; months/years use the date.
    String labelAt(int i) => period.isWeek
        ? 'สัปดาห์ ${i + 1}'
        : _barLabel(aggs[i].period, locale);
    String rowLabelAt(int i) => period.isWeek
        ? 'สัปดาห์ ${i + 1}'
        : _rowLabel(aggs[i].period, locale);

    // Bottom list: month runs Jan→focused month (newest first) so tapping a bar
    // trims it; week ascends 1..N; year is newest first.
    final List<int> listOrder;
    if (period.isMonth) {
      final focusedIdx = aggs.indexOf(focused);
      listOrder = [for (var i = focusedIdx; i >= 0; i--) i];
    } else if (period.isWeek) {
      listOrder = [for (var i = 0; i < aggs.length; i++) i];
    } else {
      listOrder = [for (var i = aggs.length - 1; i >= 0; i--) i];
    }

    return SubScreenScaffold(
      title: 'เปรียบเทียบ',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        children: [
          PeriodChip(
            label: period.label(locale),
            onTapLabel: () => showPeriodPickerSheet(context),
            onPrev: () => ref.read(selectedPeriodProvider.notifier).previous(),
            onNext: () => ref.read(selectedPeriodProvider.notifier).next(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroCard(
                  label: 'เก็บได้${period.periodNoun(locale)}',
                  value: Money.compact(current.saved),
                  background: AppColors.greenTint,
                  foreground: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroCard(
                  label: 'เฉลี่ย ${aggs.length} $unitWord',
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
                const SizedBox(height: 10),
                _TappedSummary(
                  label: labelAt(aggs.indexOf(focused)),
                  income: focused.income,
                  expense: focused.expense,
                ),
                const SizedBox(height: 14),
                GroupedBarChart(
                  groupWidth: aggs.length > 7 ? 42 : null,
                  onBarTap: (i) =>
                      setState(() => _focused = aggs[i].period),
                  groups: [
                    for (var i = 0; i < aggs.length; i++)
                      BarGroupData(
                        label: labelAt(i),
                        income: aggs[i].income / 100.0,
                        expense: aggs[i].expense / 100.0,
                        active: aggs[i].period == focused.period,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('ราย$unitWord',
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
                for (var j = 0; j < listOrder.length; j++) ...[
                  if (j > 0) const Divider(height: 1),
                  _PeriodRow(
                    label: rowLabelAt(listOrder[j]),
                    agg: aggs[listOrder[j]],
                    active: aggs[listOrder[j]].period == focused.period,
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

/// One-line readout of the tapped (or selected) bar's income / expense / saved.
class _TappedSummary extends StatelessWidget {
  const _TappedSummary({
    required this.label,
    required this.income,
    required this.expense,
  });
  final String label;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final saved = (income - expense) < 0 ? 0 : income - expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label,
              style: AppTypography.heading(size: 13, weight: FontWeight.w600)),
          const Spacer(),
          _Stat(label: 'รายรับ', value: income, color: AppColors.green),
          const SizedBox(width: 12),
          _Stat(label: 'รายจ่าย', value: expense, color: AppColors.terra),
          const SizedBox(width: 12),
          _Stat(label: 'เก็บได้', value: saved, color: AppColors.ink),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: AppTypography.body(size: 10, color: AppColors.ink3)),
        Text(Money.compact(value),
            style: AppTypography.heading(
                size: 12.5, weight: FontWeight.w600, color: color)),
      ],
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: AppTypography.heading(
                    size: 22, weight: FontWeight.w600, color: foreground)),
          ),
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

/// Bar-chart x-axis label for a period (compact): short month, week start day,
/// or year.
String _barLabel(DatePeriod p, String locale) => switch (p.mode) {
      PeriodMode.month => AppDate.formatMonthShort(p.anchor, locale: locale),
      PeriodMode.week => AppDate.formatDayShort(p.anchor, locale: locale),
      PeriodMode.year => AppDate.formatYear(p.anchor, locale: locale),
    };

/// Full row label for a period: full month name, week range, or year.
String _rowLabel(DatePeriod p, String locale) => switch (p.mode) {
      PeriodMode.month => AppDate.formatMonthName(p.anchor, locale: locale),
      PeriodMode.week => AppDate.formatWeekRange(p.anchor, locale: locale),
      PeriodMode.year => AppDate.formatYear(p.anchor, locale: locale),
    };

class _PeriodRow extends StatelessWidget {
  const _PeriodRow(
      {required this.label, required this.agg, required this.active});
  final String label;
  final _PeriodAgg agg;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: active ? AppColors.terraWash : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(Money.compact(agg.saved),
                      maxLines: 1,
                      style: AppTypography.heading(
                          size: 14, weight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
