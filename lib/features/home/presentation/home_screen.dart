import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/bun_scanning_block.dart';
import '../../../core/widgets/period_chip.dart';
import '../../../core/widgets/stat_chip.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../transactions/presentation/widgets/txn_day_group.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-read slips once per app open (the guard lives on the controller so
    // it fires once per launch even if Home is rebuilt by bottom-nav).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanControllerProvider.notifier).autoScanOnce();
    });
  }

  Future<void> _scan() => ref.read(scanControllerProvider.notifier).scan();

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final period = ref.watch(selectedPeriodProvider);
    final txns = ref.watch(periodTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a
    };
    final budgets = ref.watch(budgetsProvider).value ?? const <BudgetRow>[];
    final settings = ref.watch(appSettingsProvider).value;
    final scan = ref.watch(scanControllerProvider);

    _listenScan();

    final expense = txns
        .where((t) => t.type == TxnType.expense)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final income = txns
        .where((t) => t.type == TxnType.income)
        .fold<int>(0, (s, t) => s + t.amountCents);
    // Sum of monthly budgets, prorated to the week (× 7/days) in week mode so
    // the spending card compares like-for-like with the period's spending.
    final monthlyBudget = budgets
        .where((b) => b.period == BudgetPeriod.monthly)
        .fold<int>(0, (s, b) => s + b.amountCents);
    final totalBudget = (monthlyBudget * period.monthlyProration).round();

    // The home recent list surfaces only the actionable, still-uncategorised
    // slip imports (newest first, capped); everything else lives on
    // /transactions. Transfers/income are excluded — they need no category.
    final recentUncategorized = txns
        .where(TxnDayGroup.isUncategorized)
        .sorted((a, b) => b.occurredAt.compareTo(a.occurredAt))
        .take(10)
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          // Bouncing physics on every platform so the Cupertino-style refresh
          // control (Bun scanning block) can be revealed by overscroll.
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // Pull-to-refresh: NO Material spinner — just a pull hint. The
            // "น้องบันกำลังอ่านสลิป" scanning block now lives in the body
            // (between the header and the month chip).
            CupertinoSliverRefreshControl(
              refreshTriggerPullDistance: 110,
              refreshIndicatorExtent: 0,
              onRefresh: _scan,
              builder: _buildRefreshIndicator,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
              sliver: SliverToBoxAdapter(
                child: StaggeredColumn(
                  spacing: 18,
                  children: [
                    const _Header(),
                    if (scan.scanning) const BunScanningBlock(),
                    PeriodChip(
                      label: period.label(locale),
                      onTapLabel: () => showPeriodPickerSheet(context),
                      onPrev: () =>
                          ref.read(selectedPeriodProvider.notifier).previous(),
                      onNext: () =>
                          ref.read(selectedPeriodProvider.notifier).next(),
                    ),
                    _SpendingCard(
                      spentCents: expense,
                      budgetCents: totalBudget,
                      subtitleNoun: period.periodNoun(locale),
                      scanning: scan.scanning,
                      lastReadAt: settings?.lastSlipReadAt,
                      onRefresh: _scan,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: StatChip(
                            icon: AppIcons.arrowDownLeft,
                            label: 'รายรับ',
                            amount: Money.compact(income),
                            accent: AppColors.green,
                            amountColor: AppColors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatChip(
                            icon: AppIcons.arrowUpRight,
                            label: 'รายจ่าย',
                            amount: Money.compact(expense),
                            accent: AppColors.terra,
                          ),
                        ),
                      ],
                    ),
                    _RecentHeader(
                        onSeeAll: () => context.push('/transactions')),
                    _RecentList(
                      uncategorized: recentUncategorized,
                      categories: categories,
                      accounts: accounts,
                      locale: locale,
                      onTapTxn: (id) =>
                          showAddTransactionSheet(context, editId: id),
                      onCategorize: _categorize,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom pull-to-refresh chrome — replaces the Material circular spinner.
  Widget _buildRefreshIndicator(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulledExtent,
    double triggerDistance,
    double indicatorExtent,
  ) {
    switch (mode) {
      case RefreshIndicatorMode.drag:
        return const _PullHint(armed: false);
      case RefreshIndicatorMode.armed:
        return const _PullHint(armed: true);
      case RefreshIndicatorMode.refresh:
      case RefreshIndicatorMode.done:
      case RefreshIndicatorMode.inactive:
        return const SizedBox.shrink();
    }
  }

  void _listenScan() {
    ref.listen<ScanState>(scanControllerProvider, (prev, next) {
      if (next.permissionDenied && !(prev?.permissionDenied ?? false)) {
        _permissionDialog();
      } else if ((prev?.scanning ?? false) &&
          !next.scanning &&
          next.error == null &&
          next.result != null) {
        final r = next.result!;
        if (r.imported > 0) {
          _snack('น้องบันอ่านสลิปใหม่ ${r.imported} รายการ');
        }
      } else if (next.error != null && prev?.error != next.error) {
        _snack('สแกนไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
    });
  }

  Future<void> _categorize(TransactionRow txn) async {
    final pick = await showCategoryPicker(context);
    if (pick != null) {
      await ref
          .read(transactionRepositoryProvider)
          .setCategory(txn.id, pick.categoryId);
      if (pick.tagIds.isNotEmpty) {
        await ref
            .read(databaseProvider)
            .setTransactionTags(txn.id, pick.tagIds);
      }
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _permissionDialog() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ขอสิทธิ์เข้าถึงรูปภาพ'),
        content: const Text(
          'MoneyBun ต้องเข้าถึงรูปในเครื่องเพื่ออ่านสลิปจากแกลเลอรี\n\n'
          'ถ้าเคยกด "ไม่อนุญาต" ไปแล้ว ให้เปิดการตั้งค่า → สิทธิ์ → '
          'รูปภาพและวิดีโอ → อนุญาต',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('เปิดการตั้งค่า')),
        ],
      ),
    );
    if (open == true) await ref.read(slipImporterProvider).openSettings();
  }
}

/// Pull-to-refresh hint shown while dragging (before the scan starts).
class _PullHint extends StatelessWidget {
  const _PullHint({required this.armed});
  final bool armed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: armed ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(AppIcons.arrowDown,
                  size: 16, color: AppColors.terra),
            ),
            const SizedBox(width: 8),
            Text(
              armed ? 'ปล่อยเพื่อให้น้องบันอ่านสลิป' : 'ดึงลงเพื่ออัปเดตสลิป',
              style: AppTypography.body(size: 13.5, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'สวัสดีตอนเช้า'
        : (hour < 17 ? 'สวัสดีตอนบ่าย' : 'สวัสดีตอนเย็น');
    final name = ref.watch(appSettingsProvider).value?.displayName ?? 'คุณบัน';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: AppTypography.body(size: 13, color: AppColors.ink3)),
              Text(name,
                  style:
                      AppTypography.heading(size: 20, weight: FontWeight.w600)),
            ],
          ),
        ),
        _WalletButton(onTap: () => showAccountsSheet(context)),
      ],
    );
  }
}

class _WalletButton extends StatelessWidget {
  const _WalletButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.terraWash,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: const Icon(AppIcons.wallet, size: 22, color: AppColors.terra700),
      ),
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.spentCents,
    required this.budgetCents,
    required this.subtitleNoun,
    required this.scanning,
    required this.lastReadAt,
    required this.onRefresh,
  });

  final int spentCents;
  final int budgetCents;
  final String subtitleNoun;
  final bool scanning;
  final int? lastReadAt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasBudget = budgetCents > 0;
    final remaining = budgetCents - spentCents;
    final progress =
        hasBudget ? (spentCents / budgetCents).clamp(0.0, 1.0) : 0.0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.terra,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -8,
            child: Opacity(
              opacity: 0.9,
              child: const BunAvatar(size: 76, variant: BunVariant.reverse),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ใช้จ่าย$subtitleNoun',
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.reverse.withValues(alpha: 0.82))),
              const SizedBox(height: 2),
              Text(Money.compact(spentCents),
                  style: AppTypography.heading(
                      size: 38,
                      weight: FontWeight.w600,
                      color: AppColors.reverse)),
              const SizedBox(height: 2),
              Text(
                hasBudget
                    ? 'เหลือ ${Money.compact(remaining)} จากงบ ${Money.compact(budgetCents)}'
                    : 'ยังไม่ได้ตั้งงบประมาณเดือนนี้',
                style: AppTypography.body(
                    size: 13, color: AppColors.reverse.withValues(alpha: 0.82)),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: AppColors.reverse.withValues(alpha: 0.28),
                  valueColor: const AlwaysStoppedAnimation(AppColors.reverse),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0x33FBF4EE), thickness: 1),
              const SizedBox(height: 10),
              InkWell(
                onTap: scanning ? null : () => onRefresh(),
                child: Row(
                  children: [
                    Icon(scanning ? AppIcons.loader : AppIcons.receiptText,
                        size: 14, color: AppColors.reverse),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        scanning
                            ? 'น้องบันกำลังอ่านสลิป…'
                            : 'อ่านสลิปล่าสุด ${_relative(lastReadAt)}',
                        style: AppTypography.body(
                            size: 12,
                            color: AppColors.reverse.withValues(alpha: 0.82)),
                      ),
                    ),
                    if (!scanning)
                      Icon(AppIcons.rotateCw,
                          size: 14,
                          color: AppColors.reverse.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relative(int? ms) {
    if (ms == null) return 'ยังไม่เคยอ่าน';
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return 'เมื่อ ${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return 'เมื่อ ${diff.inHours} ชม.ที่แล้ว';
    return 'เมื่อ ${diff.inDays} วันก่อน';
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('รายการล่าสุด',
            style: AppTypography.heading(size: 16, weight: FontWeight.w500)),
        InkWell(
          onTap: onSeeAll,
          child: Text('ดูทั้งหมด',
              style: AppTypography.heading(
                  size: 13, weight: FontWeight.w400, color: AppColors.terra)),
        ),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.uncategorized,
    required this.categories,
    required this.accounts,
    required this.locale,
    required this.onTapTxn,
    required this.onCategorize,
  });

  final List<TransactionRow> uncategorized;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final String locale;
  final void Function(String id) onTapTxn;
  final void Function(TransactionRow) onCategorize;

  @override
  Widget build(BuildContext context) {
    if (uncategorized.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const BunAvatar(size: 72),
            const SizedBox(height: 12),
            Text('ไม่มีรายการที่ต้องจัดหมวด',
                style:
                    AppTypography.heading(size: 15, weight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('ดึงลงเพื่อให้น้องบันอ่านสลิป หรือกด +',
                style: AppTypography.body(size: 13, color: AppColors.ink3)),
          ],
        ),
      );
    }
    final byDay = groupBy<TransactionRow, DateTime>(
      uncategorized,
      (t) => AppDate.startOfDay(AppDate.fromMillis(t.occurredAt)),
    );
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      children: [
        for (final day in days)
          TxnDayGroup(
            day: day,
            rows: byDay[day]!,
            categories: categories,
            accounts: accounts,
            locale: locale,
            onTapTxn: onTapTxn,
            onCategorize: onCategorize,
          ),
      ],
    );
  }
}
