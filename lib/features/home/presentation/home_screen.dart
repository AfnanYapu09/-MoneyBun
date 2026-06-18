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
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/stat_chip.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../transactions/presentation/txn_display.dart';
import '../../transactions/presentation/widgets/txn_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _scan() => ref.read(scanControllerProvider.notifier).scan();

  @override
  Widget build(BuildContext context) {
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
    final totalBudget = budgets
        .where((b) => b.period == BudgetPeriod.monthly)
        .fold<int>(0, (s, b) => s + b.amountCents);

    // The freshly-scanned, uncategorized slip (if any).
    final scanned = txns
        .where((t) =>
            t.type == TxnType.expense &&
            t.categoryId == null &&
            t.slipId != null)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final scannedRow = scanned.isEmpty ? null : scanned.first;

    final recent = txns.where((t) => t.id != scannedRow?.id).take(6).toList();
    final watchedCount = accounts.values.where((a) => a.watchedForSlips).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.terra,
          onRefresh: _scan,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
            children: [
              if (scan.scanning) ...[
                const BunScanningBlock(),
                const SizedBox(height: 18),
              ],
              StaggeredColumn(
                spacing: 18,
                children: [
                  _Header(watchedCount: watchedCount),
                  MonthChip(
                    label: AppDate.formatMonth(month, locale: locale),
                    onPrev: () =>
                        ref.read(selectedMonthProvider.notifier).previous(),
                    onNext: () =>
                        ref.read(selectedMonthProvider.notifier).next(),
                  ),
                  _SpendingCard(
                    spentCents: expense,
                    budgetCents: totalBudget,
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
                  _RecentHeader(onSeeAll: () => context.push('/transactions')),
                  _RecentList(
                    scannedRow: scannedRow,
                    recent: recent,
                    categories: categories,
                    accounts: accounts,
                    locale: locale,
                    onCategorize: _categorize,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _Header extends ConsumerWidget {
  const _Header({required this.watchedCount});
  final int watchedCount;

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
        _WalletButton(
            count: watchedCount, onTap: () => showAccountsSheet(context)),
      ],
    );
  }
}

class _WalletButton extends StatelessWidget {
  const _WalletButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.terraWash,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: const BunAvatar(size: 32),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.terra,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cream, width: 2),
                ),
                child: const Icon(AppIcons.wallet,
                    size: 12, color: AppColors.reverse),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 0,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  constraints:
                      const BoxConstraints(minWidth: 17, minHeight: 17),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.cream, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text('$count',
                      style: AppTypography.heading(
                          size: 10,
                          weight: FontWeight.w500,
                          color: AppColors.reverse)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.spentCents,
    required this.budgetCents,
    required this.scanning,
    required this.lastReadAt,
    required this.onRefresh,
  });

  final int spentCents;
  final int budgetCents;
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
      decoration: BoxDecoration(
        color: AppColors.terra,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: 6,
            child: Opacity(
              opacity: 0.9,
              child: const BunAvatar(size: 64, variant: BunVariant.reverse),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ใช้จ่ายเดือนนี้',
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
    required this.scannedRow,
    required this.recent,
    required this.categories,
    required this.accounts,
    required this.locale,
    required this.onCategorize,
  });

  final TransactionRow? scannedRow;
  final List<TransactionRow> recent;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final String locale;
  final Future<void> Function(TransactionRow) onCategorize;

  @override
  Widget build(BuildContext context) {
    if (scannedRow == null && recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const BunAvatar(size: 72),
            const SizedBox(height: 12),
            Text('ยังไม่มีรายการเดือนนี้',
                style:
                    AppTypography.heading(size: 15, weight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('ดึงลงเพื่อให้น้องบันอ่านสลิป หรือกด +',
                style: AppTypography.body(size: 13, color: AppColors.ink3)),
          ],
        ),
      );
    }
    final children = <Widget>[];
    if (scannedRow != null) {
      children.add(_ScannedRow(
          txn: scannedRow!, onTap: () => onCategorize(scannedRow!)));
    }
    for (var i = 0; i < recent.length; i++) {
      final t = recent[i];
      final d = txnDisplay(t,
          categories: categories, accounts: accounts, locale: locale);
      children.add(TxnRow(
        icon: d.icon,
        title: d.title,
        sub: d.sub,
        amountCents: t.amountCents,
        type: t.type,
        onTap: () => context.push('/transactions/${t.id}'),
      ));
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ],
    );
  }
}

class _ScannedRow extends StatelessWidget {
  const _ScannedRow({required this.txn, required this.onTap});
  final TransactionRow txn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: onTap,
            customBorder:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.terra, width: 2, style: BorderStyle.solid),
              ),
              child: const Icon(AppIcons.plus,
                  size: 20, color: AppColors.terra700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รายการใหม่จากสลิป',
                    style: AppTypography.heading(
                        size: 15, weight: FontWeight.w500)),
                Text('แตะไอคอนเพื่อจัดหมวดหมู่',
                    style:
                        AppTypography.body(size: 12.5, color: AppColors.terra)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('−${Money.compact(txn.amountCents.abs())}',
              style: AppTypography.heading(size: 15, weight: FontWeight.w500)),
        ],
      ),
    );
  }
}
