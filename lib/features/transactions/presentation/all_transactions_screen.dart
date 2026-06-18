import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import 'txn_display.dart';
import 'widgets/txn_row.dart';

/// Full-screen list of all transactions for the selected month, grouped by day.
class AllTransactionsScreen extends ConsumerWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).languageCode;
    final month = ref.watch(selectedMonthProvider);
    final txns = ref.watch(monthTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a
    };

    final byDay = groupBy<TransactionRow, DateTime>(
      txns,
      (t) => AppDate.startOfDay(AppDate.fromMillis(t.occurredAt)),
    );
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return SubScreenScaffold(
      title: 'รายการทั้งหมด',
      action: IconButton(
        onPressed: () => context.push('/search'),
        icon: const Icon(AppIcons.search, size: 21, color: AppColors.ink2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        children: [
          MonthChip(
            label: AppDate.formatMonth(month, locale: locale),
            onPrev: () => ref.read(selectedMonthProvider.notifier).previous(),
            onNext: () => ref.read(selectedMonthProvider.notifier).next(),
          ),
          const SizedBox(height: 6),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text('ยังไม่มีรายการเดือนนี้',
                    style: AppTypography.body(size: 14, color: AppColors.ink3)),
              ),
            ),
          for (final day in days)
            _DayGroup(
              day: day,
              rows: byDay[day]!,
              categories: categories,
              accounts: accounts,
              locale: locale,
            ),
        ],
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.day,
    required this.rows,
    required this.categories,
    required this.accounts,
    required this.locale,
  });

  final DateTime day;
  final List<TransactionRow> rows;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final net = rows.fold<int>(
        0,
        (s, t) => switch (t.type) {
              TxnType.income => s + t.amountCents,
              TxnType.expense => s - t.amountCents,
              TxnType.transfer => s,
            });
    final netStr =
        '${net > 0 ? '+' : net < 0 ? '−' : ''}${Money.compact(net.abs())}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppDate.relativeDayLabel(day, locale: locale),
                  style:
                      AppTypography.heading(size: 15, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(AppDate.formatWeekday(day, locale: locale),
                  style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
              const Spacer(),
              Text(netStr,
                  style: AppTypography.heading(
                      size: 13.5,
                      weight: FontWeight.w500,
                      color: net > 0 ? AppColors.green : AppColors.ink2)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Builder(builder: (context) {
                  final t = rows[i];
                  final d = txnDisplay(t,
                      categories: categories,
                      accounts: accounts,
                      locale: locale);
                  return TxnRow(
                    icon: d.icon,
                    title: d.title,
                    sub: d.sub,
                    amountCents: t.amountCents,
                    type: t.type,
                    onTap: () => context.push('/transactions/${t.id}'),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
