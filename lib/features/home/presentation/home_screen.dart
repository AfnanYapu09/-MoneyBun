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
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/slip_image.dart';
import '../../../data/local/database.dart';

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
        c.id: c,
    };
    final slips =
        ref.watch(slipsByIdProvider).value ?? const <String, SlipRow>{};
    final scan = ref.watch(scanControllerProvider);

    // React to scan results: toast the count, or prompt for photo permission.
    ref.listen<ScanState>(scanControllerProvider, (prev, next) {
      if (next.permissionDenied && !(prev?.permissionDenied ?? false)) {
        _showPermissionDialog();
      } else if ((prev?.scanning ?? false) &&
          !next.scanning &&
          next.error == null &&
          !next.permissionDenied) {
        final n = next.lastImported ?? 0;
        _snack(n > 0 ? 'น้องบันอ่านสลิปใหม่ $n รายการ' : 'ไม่พบสลิปใหม่');
      } else if (next.error != null && prev?.error != next.error) {
        _snack('สแกนไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
    });

    final total = txns.fold<int>(0, (s, t) => s + t.amountCents);
    final byDay = groupBy<TransactionRow, DateTime>(
      txns,
      (t) => AppDate.startOfDay(AppDate.fromMillis(t.occurredAt)),
    );
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(month: month, locale: locale, total: total),
            if (scan.scanning) const _ScanningBanner(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.bunOrange,
                onRefresh: _scan,
                child: txns.isEmpty
                    ? _EmptyState(onScan: _scan)
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        children: [
                          for (final day in days)
                            _DaySection(
                              day: day,
                              rows: byDay[day]!,
                              categories: categories,
                              slips: slips,
                              locale: locale,
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

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _showPermissionDialog() async {
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
  const _Header(
      {required this.month, required this.locale, required this.total});

  final DateTime month;
  final String locale;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              const BunAvatar(size: 40, mood: BunMood.happy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppDate.formatMonth(month, locale: locale),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).previous(),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).next(),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          PixelBorder(
            color: AppColors.orangeLight,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('รวมเดือนนี้',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(Money.format(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: AppColors.expense)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated banner shown while a scan runs (pulsing Bun + progress bar).
class _ScanningBanner extends StatefulWidget {
  const _ScanningBanner();

  @override
  State<_ScanningBanner> createState() => _ScanningBannerState();
}

class _ScanningBannerState extends State<_ScanningBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: PixelBorder(
        color: AppColors.orangeLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.12).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeInOut),
              ),
              child: const BunAvatar(size: 34, mood: BunMood.happy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('น้องบันกำลังอ่านสลิป...',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      minHeight: 6,
                      backgroundColor: AppColors.gray100,
                      color: AppColors.bunOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.rows,
    required this.categories,
    required this.slips,
    required this.locale,
  });

  final DateTime day;
  final List<TransactionRow> rows;
  final Map<String, CategoryRow> categories;
  final Map<String, SlipRow> slips;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final dayTotal = rows.fold<int>(0, (s, t) => s + t.amountCents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(AppDate.formatDayHeader(day, locale: locale),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.gray700)),
              ),
              Text(Money.format(dayTotal, symbol: false),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.expense)),
            ],
          ),
        ),
        for (final t in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SlipTile(
              txn: t,
              slip: t.slipId == null ? null : slips[t.slipId],
              category: t.categoryId == null ? null : categories[t.categoryId],
              locale: locale,
            ),
          ),
      ],
    );
  }
}

class _SlipTile extends ConsumerWidget {
  const _SlipTile({
    required this.txn,
    required this.slip,
    required this.category,
    required this.locale,
  });

  final TransactionRow txn;
  final SlipRow? slip;
  final CategoryRow? category;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PixelBorder(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/entry?id=${txn.id}'),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SlipImage(slip: slip),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Money.format(txn.amountCents),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  AppDate.formatTime(AppDate.fromMillis(txn.occurredAt),
                      locale: locale),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.gray400),
                ),
                const SizedBox(height: 6),
                _CategoryChip(
                  category: category,
                  onTap: () => _pickCategory(context, ref),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray300),
        ],
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, WidgetRef ref) async {
    final categories = ref.read(categoriesProvider).value ?? const [];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _CategorySheet(categories: categories),
    );
    if (picked != null) {
      await ref.read(transactionRepositoryProvider).setCategory(txn.id, picked);
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final CategoryRow? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = category;
    final color =
        c == null ? AppColors.bunOrange : AppColors.forHex(c.colorHex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              c == null ? AppColors.orangeLight : color.withValues(alpha: 0.15),
          borderRadius: PixelTokens.borderRadius,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(c == null ? Icons.add : CategoryIcons.forKey(c.iconKey),
                size: 14, color: color),
            const SizedBox(width: 4),
            Text(c?.name ?? 'เลือกหมวดหมู่',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.categories});
  final List<CategoryRow> categories;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('เลือกหมวดหมู่',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  GestureDetector(
                    onTap: () => Navigator.pop(context, c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: PixelTokens.borderRadius,
                        border: PixelTokens.inkBorder(color: AppColors.gray300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CategoryIcons.forKey(c.iconKey),
                              size: 18, color: AppColors.forHex(c.colorHex)),
                          const SizedBox(width: 6),
                          Text(c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});

  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 72),
        const BunAvatar(size: 100, mood: BunMood.sleepy),
        const SizedBox(height: 16),
        const Text('ยังไม่มีสลิป',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'เลื่อนลงเพื่อให้น้องบันอ่านสลิปจากรูปในเครื่องอัตโนมัติ',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray500),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: PixelButton(
            label: 'อ่านสลิปเลย',
            icon: Icons.refresh,
            onPressed: () => onScan(),
          ),
        ),
      ],
    );
  }
}
