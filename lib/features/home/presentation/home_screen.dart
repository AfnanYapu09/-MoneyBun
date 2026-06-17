import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/pixel_theme.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/pixel_border.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(monthTransactionsProvider);
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _MonthHeader(
              month: month,
              locale: locale,
              onPrev: () => ref.read(selectedMonthProvider.notifier).previous(),
              onNext: () => ref.read(selectedMonthProvider.notifier).next(),
            ),
            Expanded(
              child: txnsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (txns) {
                  if (txns.isEmpty) {
                    return _EmptyState(l10n: l10n);
                  }
                  return _DailyList(
                    txns: txns,
                    categories: categories,
                    accounts: accounts,
                    locale: locale,
                    l10n: l10n,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.locale,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final String locale;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const BunAvatar(size: 40, mood: BunMood.happy),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppDate.formatMonth(month, locale: locale),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({
    required this.txns,
    required this.categories,
    required this.accounts,
    required this.locale,
    required this.l10n,
  });

  final List<TransactionRow> txns;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final income = txns
        .where((t) => t.type == TxnType.income)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final expense = txns
        .where((t) => t.type == TxnType.expense)
        .fold<int>(0, (s, t) => s + t.amountCents);

    final byDay = groupBy<TransactionRow, DateTime>(
      txns,
      (t) => AppDate.startOfDay(AppDate.fromMillis(t.occurredAt)),
    );
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        _SummaryCard(income: income, expense: expense, l10n: l10n),
        const SizedBox(height: 12),
        for (final day in days)
          _DaySection(
            day: day,
            rows: byDay[day]!,
            categories: categories,
            accounts: accounts,
            locale: locale,
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.l10n,
  });

  final int income;
  final int expense;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PixelBorder(
      color: AppColors.orangeLight,
      child: Row(
        children: [
          _stat(l10n.income, income, AppColors.income),
          _divider(),
          _stat(l10n.expense, expense, AppColors.expense),
          _divider(),
          _stat(l10n.balance, income - expense, AppColors.ink),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1.5, height: 36, color: AppColors.ink.withValues(alpha: 0.2));

  Widget _stat(String label, int cents, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              Money.format(cents, symbol: false),
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: color, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
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
    final dayTotal = rows.fold<int>(0, (s, t) {
      switch (t.type) {
        case TxnType.income:
          return s + t.amountCents;
        case TxnType.expense:
          return s - t.amountCents;
        case TxnType.transfer:
          return s;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppDate.formatDayHeader(day, locale: locale),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.gray700,
                  ),
                ),
              ),
              Text(
                Money.formatSigned(dayTotal, symbol: false),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: dayTotal >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ),
        PixelBorder(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1.5, thickness: 1.5, color: AppColors.gray100),
                _TxnTile(
                  txn: rows[i],
                  category: categories[rows[i].categoryId],
                  account: accounts[rows[i].accountId],
                  toAccount: accounts[rows[i].toAccountId],
                  locale: locale,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({
    required this.txn,
    required this.category,
    required this.account,
    required this.toAccount,
    required this.locale,
  });

  final TransactionRow txn;
  final CategoryRow? category;
  final AccountRow? account;
  final AccountRow? toAccount;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final color = switch (txn.type) {
      TxnType.income => AppColors.income,
      TxnType.expense => AppColors.expense,
      TxnType.transfer => AppColors.transfer,
    };
    final icon = switch (txn.type) {
      TxnType.transfer => Icons.swap_horiz,
      _ => CategoryIcons.forKey(category?.iconKey),
    };
    final title = switch (txn.type) {
      TxnType.transfer => '${account?.name ?? '?'} → ${toAccount?.name ?? '?'}',
      _ => category?.name ?? txn.note ?? '-',
    };
    final signed =
        txn.type == TxnType.expense ? -txn.amountCents : txn.amountCents;

    return InkWell(
      onTap: () => context.push('/add?id=${txn.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: PixelTokens.borderRadius,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if ((txn.note ?? '').isNotEmpty &&
                      txn.type != TxnType.transfer)
                    Text(
                      txn.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.gray500),
                    ),
                  Text(
                    '${account?.name ?? ''} · ${AppDate.formatTime(AppDate.fromMillis(txn.occurredAt), locale: locale)}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.gray400),
                  ),
                ],
              ),
            ),
            Text(
              Money.formatSigned(signed, symbol: false),
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BunAvatar(size: 96, mood: BunMood.sleepy),
          const SizedBox(height: 16),
          Text(
            l10n.emptyDayTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.emptyDaySubtitle,
            style: const TextStyle(color: AppColors.gray500),
          ),
        ],
      ),
    );
  }
}
