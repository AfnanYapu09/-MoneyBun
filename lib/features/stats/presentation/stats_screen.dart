import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/pixel_border.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final month = ref.watch(selectedMonthProvider);
    final txns = ref.watch(monthTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };

    final income = txns
        .where((t) => t.type == TxnType.income)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final expense = txns
        .where((t) => t.type == TxnType.expense)
        .fold<int>(0, (s, t) => s + t.amountCents);

    final byCategory = <String, int>{};
    for (final t in txns.where((t) => t.type == TxnType.expense)) {
      final key = t.categoryId ?? 'sys_other_expense';
      byCategory.update(key, (v) => v + t.amountCents,
          ifAbsent: () => t.amountCents);
    }
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = ranked.isEmpty ? 1 : ranked.first.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stats)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).previous(),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  AppDate.formatMonth(month, locale: locale),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).next(),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _StatBox(
                      label: l10n.income,
                      cents: income,
                      color: AppColors.income)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatBox(
                      label: l10n.expense,
                      cents: expense,
                      color: AppColors.expense)),
            ],
          ),
          const SizedBox(height: 12),
          _StatBox(
              label: l10n.balance,
              cents: income - expense,
              color: AppColors.ink),
          const SizedBox(height: 20),
          Text(l10n.byCategory,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          if (ranked.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(l10n.noData,
                    style: const TextStyle(color: AppColors.gray500)),
              ),
            )
          else
            for (final e in ranked)
              _CategoryBar(
                category: categories[e.key],
                cents: e.value,
                fraction: e.value / maxCat,
                share: expense == 0 ? 0 : e.value / expense,
              ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label, required this.cents, required this.color});

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PixelBorder(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.gray600, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              Money.format(cents),
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 20, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.cents,
    required this.fraction,
    required this.share,
  });

  final CategoryRow? category;
  final int cents;
  final double fraction;
  final double share;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forHex(category?.colorHex ?? 'FF7A736B');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(CategoryIcons.forKey(category?.iconKey),
                  size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(category?.name ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text('${(share * 100).round()}%  ',
                  style:
                      const TextStyle(color: AppColors.gray500, fontSize: 12)),
              Text(Money.format(cents, symbol: false),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.02, 1),
              minHeight: 10,
              backgroundColor: AppColors.gray100,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
