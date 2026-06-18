import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/pixel_border.dart';
import '../../../data/local/database.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).languageCode;
    final month = ref.watch(selectedMonthProvider);
    final txns = ref.watch(monthTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };

    final total = txns.fold<int>(0, (s, t) => s + t.amountCents);
    final byCategory = <String, int>{};
    for (final t in txns) {
      final key = t.categoryId ?? 'sys_other';
      byCategory.update(key, (v) => v + t.amountCents,
          ifAbsent: () => t.amountCents);
    }
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = ranked.isEmpty ? 1 : ranked.first.value;

    return Scaffold(
      appBar: AppBar(title: const Text('สถิติ')),
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
                child: Text(AppDate.formatMonth(month, locale: locale),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).next(),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PixelBorder(
            color: AppColors.orangeLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รวมรายจ่ายเดือนนี้',
                    style: TextStyle(color: AppColors.gray700, fontSize: 13)),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(Money.format(total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          color: AppColors.expense)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('แยกตามหมวดหมู่',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          if (ranked.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('ยังไม่มีข้อมูล',
                      style: TextStyle(color: AppColors.gray500))),
            )
          else
            for (final e in ranked)
              _CategoryBar(
                category: categories[e.key],
                cents: e.value,
                fraction: e.value / maxCat,
                share: total == 0 ? 0 : e.value / total,
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
                child: Text(category?.name ?? 'อื่นๆ',
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
