import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/period_chip.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/progress.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/week_strip.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../transactions/presentation/txn_display.dart';
import '../../transactions/presentation/widgets/txn_row.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  static const _palette = [
    AppColors.terra,
    AppColors.terraDeep,
    Color(0xFFD98C6F),
    AppColors.green,
    Color(0xFFCDBFB0),
  ];

  /// Which transaction type the screen breaks down (รายจ่าย / รายรับ / ย้ายเงิน).
  TxnType _type = TxnType.expense;

  /// false → breakdown by category, true → by tag.
  bool _byTag = false;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final period = ref.watch(selectedPeriodProvider);
    final txns = ref.watch(periodTransactionsProvider).value ?? const [];
    final allTxns = ref.watch(allTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a
    };
    final budgetCount =
        (ref.watch(budgetsProvider).value ?? const <BudgetRow>[])
            .where((b) => b.categoryId != null)
            .length;

    final isTransfer = _type == TxnType.transfer;

    // Transactions of the selected type, and their total.
    final selected = txns.where((t) => t.type == _type).toList();
    final total = selected.fold<int>(0, (s, t) => s + t.amountCents);
    final byCategory = <String, int>{};
    for (final t in selected) {
      final key = t.categoryId ?? 'sys_other';
      byCategory.update(key, (v) => v + t.amountCents,
          ifAbsent: () => t.amountCents);
    }
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Spending split by tag. A transaction can carry several tags, so its
    // amount counts toward each tag it has.
    final tags = {
      for (final t in ref.watch(tagsProvider).value ?? const <TagRow>[]) t.id: t
    };
    final selectedById = {for (final t in selected) t.id: t.amountCents};
    final byTag = <String, int>{};
    for (final link in ref.watch(allTransactionTagsProvider).value ??
        const <TransactionTagRow>[]) {
      final cents = selectedById[link.transactionId];
      if (cents == null) continue;
      byTag.update(link.tagId, (v) => v + cents, ifAbsent: () => cents);
    }
    final rankedTags = byTag.entries
        .where((e) => tags.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final tagTotal = rankedTags.fold<int>(0, (s, e) => s + e.value);

    // Newest-first list of transfers (shown when the ย้ายเงิน tab is active).
    final transferRows = isTransfer
        ? ([...selected]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)))
        : const <TransactionRow>[];

    // Previous-period comparison badge for the selected type.
    final prev = period.previous();
    final prevTotal = allTxns
        .where((t) =>
            t.type == _type &&
            t.occurredAt >= prev.start &&
            t.occurredAt <= prev.end)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final pctChange =
        prevTotal > 0 ? ((total - prevTotal) / prevTotal * 100).round() : null;
    final prevNoun = period.previousNoun(locale);
    Widget? badge;
    if (pctChange != null) {
      final up = pctChange > 0;
      // Rising income is good; rising spending is not; transfers are neutral.
      final good = _type == TxnType.income ? up : !up;
      badge = StatusBadge(
        icon: up ? AppIcons.arrowUpRight : AppIcons.trendingDown,
        background: isTransfer
            ? AppColors.amberWash
            : (good ? AppColors.greenTint : AppColors.terraWash),
        foreground: isTransfer
            ? AppColors.amber
            : (good ? AppColors.green : AppColors.terra700),
        label: up
            ? 'มากกว่า$prevNoun $pctChange%'
            : 'น้อยกว่า$prevNoun ${pctChange.abs()}%',
      );
    }

    final breakdownTitle =
        _type == TxnType.income ? 'เงินมาจากไหน' : 'เงินหมดไปกับอะไร';
    final donutCenter = _type == TxnType.income ? 'รายรับรวม' : 'ใช้จ่ายรวม';

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
                    if (badge != null) badge,
                  ],
                ),
                PeriodChip(
                  label: period.label(locale),
                  onTapLabel: () => showPeriodPickerSheet(context),
                  onPrev: () =>
                      ref.read(selectedPeriodProvider.notifier).previous(),
                  onNext: () =>
                      ref.read(selectedPeriodProvider.notifier).next(),
                ),
                SegmentedControl<TxnType>(
                  iconOverLabel: true,
                  value: _type,
                  onChanged: (t) => setState(() => _type = t),
                  segments: const [
                    Segment(
                        value: TxnType.expense,
                        label: 'รายจ่าย',
                        icon: AppIcons.arrowUpRight,
                        color: AppColors.terra),
                    Segment(
                        value: TxnType.income,
                        label: 'รายรับ',
                        icon: AppIcons.arrowDownLeft,
                        color: AppColors.green),
                    Segment(
                        value: TxnType.transfer,
                        label: 'ย้ายเงิน',
                        icon: AppIcons.arrowLeftRight,
                        color: AppColors.amber),
                  ],
                ),
                if (isTransfer) ...[
                  _TransferSummary(total: total, count: selected.length),
                  if (transferRows.isEmpty)
                    _emptyBreakdown('ยังไม่มีการย้ายเงิน')
                  else
                    _TransferList(
                      rows: transferRows,
                      categories: categories,
                      accounts: accounts,
                      locale: locale,
                      onTap: (id) =>
                          showAddTransactionSheet(context, editId: id),
                    ),
                ] else ...[
                  if (_type == TxnType.expense && period.isWeek)
                    WeekStrip(
                      weekStart: period.anchor,
                      dailyExpenseCents:
                          weeklyExpenseCents(period.anchor, txns),
                      locale: locale,
                    ),
                  Text(breakdownTitle,
                      style: AppTypography.heading(
                          size: 16, weight: FontWeight.w500)),
                  _DonutCard(
                      ranked: ranked,
                      total: total,
                      palette: _palette,
                      categories: categories,
                      centerLabel: donutCenter),
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
                  SegmentedControl<bool>(
                    value: _byTag,
                    onChanged: (v) => setState(() => _byTag = v),
                    segments: const [
                      Segment(value: false, label: 'ตามหมวดหมู่'),
                      Segment(value: true, label: 'ตามแท็ก'),
                    ],
                  ),
                  if (!_byTag)
                    if (ranked.isEmpty)
                      _emptyBreakdown('ยังไม่มีข้อมูล')
                    else
                      Column(
                        children: [
                          for (var i = 0; i < ranked.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _CategoryBar(
                                category: categories[ranked[i].key],
                                cents: ranked[i].value,
                                fraction:
                                    total == 0 ? 0 : ranked[i].value / total,
                                color: _palette[i % _palette.length],
                              ),
                            ),
                        ],
                      )
                  else if (rankedTags.isEmpty)
                    _emptyBreakdown('ยังไม่มีรายการที่ติดแท็ก')
                  else
                    Column(
                      children: [
                        for (var i = 0; i < rankedTags.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _TagBar(
                              tag: tags[rankedTags[i].key],
                              cents: rankedTags[i].value,
                              fraction: tagTotal == 0
                                  ? 0
                                  : rankedTags[i].value / tagTotal,
                              color: _palette[i % _palette.length],
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _emptyBreakdown(String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(message,
          style: AppTypography.body(size: 14, color: AppColors.ink3)),
    );

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.ranked,
    required this.total,
    required this.palette,
    required this.categories,
    required this.centerLabel,
  });
  final List<MapEntry<String, int>> ranked;
  final int total;
  final List<Color> palette;
  final Map<String, CategoryRow> categories;
  final String centerLabel;

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
            Text(centerLabel,
                style: AppTypography.body(size: 12, color: AppColors.ink3)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(Money.compact(total),
                  maxLines: 1,
                  style:
                      AppTypography.heading(size: 22, weight: FontWeight.w600)),
            ),
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

/// Summary card for the ย้ายเงิน tab: total moved + a count of transfers.
class _TransferSummary extends StatelessWidget {
  const _TransferSummary({required this.total, required this.count});
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          IconChip(
            icon: AppIcons.arrowLeftRight,
            size: 46,
            radius: 14,
            iconSize: 22,
            background: AppColors.amberWash,
            foreground: AppColors.amber,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ย้ายเงินรวม',
                    style:
                        AppTypography.body(size: 12.5, color: AppColors.ink3)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Money.compact(total),
                      maxLines: 1,
                      style: AppTypography.heading(
                          size: 26, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Text('$count รายการ',
              style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
        ],
      ),
    );
  }
}

/// Bordered card listing transfers, reusing the standard transaction row.
class _TransferList extends StatelessWidget {
  const _TransferList({
    required this.rows,
    required this.categories,
    required this.accounts,
    required this.locale,
    required this.onTap,
  });
  final List<TransactionRow> rows;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final String locale;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  locale: locale,
                  withDate: true);
              return TxnRow(
                icon: d.icon,
                title: d.title,
                sub: d.sub,
                iconColor: d.color,
                iconKey: d.iconKey,
                amountCents: t.amountCents,
                type: t.type,
                onTap: () => onTap(t.id),
              );
            }),
          ],
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
        if (category == null)
          IconChip(
            icon: CategoryIcons.forKey(null),
            size: 40,
            radius: 13,
            iconSize: 19,
          )
        else
          CategoryGlyph(
            iconKey: category!.iconKey,
            color: AppColors.forHex(category!.colorHex),
            size: 40,
            radius: 13,
            iconSize: 19,
          ),
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

class _TagBar extends StatelessWidget {
  const _TagBar({
    required this.tag,
    required this.cents,
    required this.fraction,
    required this.color,
  });
  final TagRow? tag;
  final int cents;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconChip(icon: AppIcons.hash, size: 40, radius: 13, iconSize: 19),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tag?.name ?? '—', style: AppTypography.body(size: 14)),
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
