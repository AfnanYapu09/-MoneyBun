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
import '../../../core/utils/budget_math.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/bun_scanning_block.dart';
import '../../../core/widgets/period_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/stat_chip.dart';
import '../../../core/widgets/sync_blur.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../transactions/presentation/widgets/account_flow.dart';
import '../../transactions/presentation/widgets/txn_day_group.dart';
import 'home_tour.dart';
import 'widgets/permission_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootFlow());
  }

  /// First-entry orchestration, in a fixed order so prompts never stack:
  /// walkthrough (first run only) → auto slip scan (which triggers the OS
  /// photo prompt) → recurring materialisation → silent permission check.
  Future<void> _bootFlow() async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.read();
    if (!mounted) return;
    if (!settings.homeTourSeen) {
      // Decide AFTER the cloud pull has landed: the walkthrough is only for
      // people who have never recorded anything. Anyone whose account already
      // holds entries knows the app — skip and never ask again.
      final sync = ref.read(syncControllerProvider);
      if (sync != null) await sync.awaitInitialSync();
      if (!mounted) return;
      await _waitForSkeletonGone();
      if (!mounted) return;
      final hasData =
          (ref.read(allTransactionsProvider).value ?? const []).isNotEmpty;
      if (hasData) {
        await repo.setHomeTourSeen(true);
      } else if (ref.read(openSheetsProvider) == 0) {
        // A sheet on top (deep link / quick FAB tap) — don't fight it; the
        // tour will run on the next launch instead.
        final shown = await HomeTour.start(context);
        if (shown) await repo.setHomeTourSeen(true);
        if (!mounted) return;
      }
    }
    // Auto-read slips once per app open (the guard lives on the controller so
    // it fires once per launch even if Home is rebuilt by bottom-nav).
    ref.read(scanControllerProvider.notifier).autoScanOnce();
    _materialiseRecurring();
    ref.read(photoPermissionProvider.notifier).refresh();
  }

  /// Wait for the first-login skeleton to clear (bounded) so the tour spot-
  /// lights real content, not shimmer placeholders.
  Future<void> _waitForSkeletonGone() async {
    for (var waited = 0; waited < 8000; waited += 250) {
      final settings = ref.read(appSettingsProvider).value;
      final hasData =
          (ref.read(allTransactionsProvider).value ?? const []).isNotEmpty;
      final loading = ref.read(initialSyncingProvider) &&
          !(settings?.firstSyncDone ?? false) &&
          !hasData;
      if (!loading) return;
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Coming back from Settings (or anywhere): re-check photo access silently.
    // If the user just granted it, drop the banner and start reading slips.
    final wasDenied =
        ref.read(photoPermissionProvider) != PhotoPermStatus.granted;
    ref.read(photoPermissionProvider.notifier).refresh().then((_) {
      if (!mounted) return;
      final now = ref.read(photoPermissionProvider);
      if (wasDenied && now == PhotoPermStatus.granted) {
        ref.read(scanControllerProvider.notifier).scan();
      }
    });
  }

  /// Create any recurring entries that have come due — but only after the
  /// first cloud pull has truly finished (no timeout escape), so we don't
  /// re-materialise occurrences another device already created and synced
  /// (which would duplicate them), and only while the plan still allows
  /// recurring rules: a downgrade to Free must stop new occurrences from
  /// appearing in the background even though existing rules are untouched.
  /// The plan is read only after the sync wait (so a just-synced upgrade on
  /// this device is seen), guarded by `mounted` since it's a `ref` read after
  /// an await.
  Future<void> _materialiseRecurring() async {
    final sync = ref.read(syncControllerProvider);
    final recurring = ref.read(recurringServiceProvider);
    if (sync != null) await sync.awaitInitialSync();
    if (!mounted) return;
    // Await the REAL membership value — planProvider's synchronous fallback
    // reports Free while the membership stream is still loading (it can only
    // resolve dev/Ultra without it), which permanently skipped runDue() for
    // Pro-by-credit users: this is the app's only runDue call site.
    final membership = await ref.read(membershipProvider.future);
    if (!mounted || !membership.plan.canUseRecurring) return;
    await recurring.runDue();
  }

  Future<void> _scan() => ref.read(scanControllerProvider.notifier).scan();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final period = ref.watch(selectedPeriodProvider);
    final txns = ref.watch(periodTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a,
    };
    final budgets = ref.watch(budgetsProvider).value ?? const <BudgetRow>[];
    final settings = ref.watch(appSettingsProvider).value;
    final scan = ref.watch(scanControllerProvider);

    // Show the first-load skeleton only on a genuinely-first login of this
    // device: the initial cloud sync is running, the device has never finished a
    // sync before, and the local DB has no transactions yet. Returning users
    // (who already have data, or whose first sync completed) go straight to
    // their data; guest / offline mode never sets the syncing flag at all. Keyed
    // on the whole DB — not the selected period — so someone with historical
    // data but no spend this month never sees a skeleton.
    final firstSyncDone = settings?.firstSyncDone ?? false;
    final hasLocalData =
        (ref.watch(allTransactionsProvider).value ?? const <TransactionRow>[])
            .isNotEmpty;
    final showLoading =
        ref.watch(initialSyncingProvider) && !firstSyncDone && !hasLocalData;
    // While the first cloud pull is streaming rows in, the visible amounts are
    // partial — blur them so they read as "loading", not as real totals.
    final blurNumbers = ref.watch(initialSyncingProvider) && !firstSyncDone;

    final periodChip = KeyedSubtree(
      key: HomeTourKeys.periodChip,
      child: PeriodChip(
        label: period.label(locale),
        onTapLabel: () => showPeriodPickerSheet(context),
        onPrev: () => ref.read(selectedPeriodProvider.notifier).previous(),
        onNext: () => ref.read(selectedPeriodProvider.notifier).next(),
      ),
    );

    _listenScan();
    // Settings → "แนะนำการใช้งาน" lands here: replay the walkthrough once the
    // Home frame is up.
    ref.listen<bool>(tourReplayProvider, (prev, next) {
      if (!next) return;
      ref.read(tourReplayProvider.notifier).clear();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Let the tab switch from Settings finish so every anchor (FAB, nav,
        // header) is measured in its settled position before spotlighting.
        await Future.delayed(const Duration(milliseconds: 350));
        if (!context.mounted || ref.read(openSheetsProvider) > 0) return;
        await HomeTour.start(context);
        await ref.read(settingsRepositoryProvider).setHomeTourSeen(true);
      });
    });

    final expense = txns
        .where((t) => t.type == TxnType.expense)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final income = txns
        .where((t) => t.type == TxnType.income)
        .fold<int>(0, (s, t) => s + t.amountCents);
    // Every budget (weekly / monthly / yearly) converted to the active window
    // so the spending card compares like-for-like with the period's spending.
    final totalBudget = budgets.fold<int>(
      0,
      (s, b) => s + budgetForWindow(b.amountCents, b.period, period),
    );

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
            parent: AlwaysScrollableScrollPhysics(),
          ),
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
                  children: showLoading
                      ? [
                          const _Header(),
                          const PermissionBanner(),
                          periodChip,
                          const _HomeSkeleton(),
                        ]
                      : [
                          const _Header(),
                          const PermissionBanner(),
                          if (scan.scanning) const BunScanningBlock(),
                          periodChip,
                          KeyedSubtree(
                            key: HomeTourKeys.spendingCard,
                            child: _SpendingCard(
                              spentCents: expense,
                              budgetCents: totalBudget,
                              subtitleNoun: period.periodNoun(locale),
                              scanning: scan.scanning,
                              lastReadAt: settings?.lastSlipReadAt,
                              onRefresh: _scan,
                              blurNumbers: blurNumbers,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: StatChip(
                                  icon: AppIcons.arrowDownLeft,
                                  label: l10n.income,
                                  amount: Money.compact(income),
                                  accent: context.palette.greenFg,
                                  amountColor: context.palette.greenFg,
                                  blurAmount: blurNumbers,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StatChip(
                                  icon: AppIcons.arrowUpRight,
                                  label: l10n.expense,
                                  amount: Money.compact(expense),
                                  accent: AppColors.terra,
                                  blurAmount: blurNumbers,
                                ),
                              ),
                            ],
                          ),
                          KeyedSubtree(
                            key: HomeTourKeys.recent,
                            child: _RecentHeader(
                              onSeeAll: () => context.push('/transactions'),
                            ),
                          ),
                          _RecentList(
                            uncategorized: recentUncategorized,
                            categories: categories,
                            accounts: accounts,
                            locale: locale,
                            onTapTxn: (id) =>
                                showAddTransactionSheet(context, editId: id),
                            onCategorize: _categorize,
                            onShowSlip: _showSlip,
                            onDelete: _deleteTxn,
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
    final l10n = AppLocalizations.of(context);
    ref.listen<ScanState>(scanControllerProvider, (prev, next) {
      if (next.waitingForRestore && !(prev?.waitingForRestore ?? false)) {
        // Manual scan while the first cloud pull is still running.
        _snack(l10n.homeScanWaitSync);
      } else if (next.permissionDenied && !(prev?.permissionDenied ?? false)) {
        // Surface the banner immediately; the styled dialog nags once per
        // app session (every cold launch) until access is granted.
        ref.read(photoPermissionProvider.notifier).markDenied();
        _permissionDialog();
      } else if (next.waitingForRestore &&
          !(prev?.waitingForRestore ?? false)) {
        // A fresh sign-in's cloud restore hasn't landed yet — the scan was
        // skipped (it re-runs by itself when the restore completes).
        _snack(l10n.homeScanWaitRestore);
      } else if ((prev?.scanning ?? false) &&
          !next.scanning &&
          next.error == null &&
          next.result != null) {
        final r = next.result!;
        // Always give feedback when a scan finishes — a silent "nothing
        // happened" looks like a bug. Distinguish "no bank album on this
        // device" from "album(s) found but no new slips".
        if (r.quotaReached) {
          // The membership limit stopped the scan (possibly mid-way) —
          // offer the referral unlock instead of a plain "imported N".
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.scanQuotaReached),
                action: SnackBarAction(
                  label: l10n.scanQuotaUpgrade,
                  onPressed: () => context.push('/settings/plan'),
                ),
              ),
            );
        } else if (r.imported > 0) {
          _snack(l10n.homeScanImported(r.imported));
          // If the newest import lands outside the month currently shown
          // (an older slip, or a date read from the slip itself), snap the
          // period onto it so the imports are never invisible.
          final ms = r.newestImportedAt;
          if (ms != null) {
            final period = ref.read(selectedPeriodProvider);
            if (ms < period.start || ms > period.end) {
              final when = DateTime.fromMillisecondsSinceEpoch(ms);
              ref.read(selectedPeriodProvider.notifier).setMonth(when);
            }
          }
        } else if (next.limited) {
          // Only selected photos shared (Android 14 partial grant) — the bank
          // album is likely hidden, so explain how to widen access.
          _snack(l10n.homeScanLimited);
        } else if (r.matchedAlbums == 0) {
          _snack(l10n.homeScanNoAlbum);
        } else {
          _snack(l10n.homeScanNoNew);
        }
      } else if (next.error != null && prev?.error != next.error) {
        _snack(l10n.homeScanFailed);
      }
    });
  }

  /// Open the source slip for a row, with a "ลบรายการ" button — used by the
  /// zero-amount warning so the user can read or delete the failed import.
  Future<void> _showSlip(TransactionRow txn) async {
    // Repos are captured before any await: the auth-state redirect can unmount
    // this screen while a viewer/dialog is up, after which ref.read throws.
    final txnRepo = ref.read(transactionRepositoryProvider);
    final slipRepo = ref.read(slipRepositoryProvider);
    final slip = txn.slipId == null ? null : await slipRepo.get(txn.slipId!);
    if (!mounted) return;
    if (slip == null) {
      showAddTransactionSheet(context, editId: txn.id);
      return;
    }
    showSlipViewer(
      context,
      slip,
      onDelete: () => txnRepo.delete(txn.id),
    );
  }

  Future<void> _categorize(TransactionRow txn) async {
    final txnRepo = ref.read(transactionRepositoryProvider);
    final slipRepo = ref.read(slipRepositoryProvider);
    final db = ref.read(databaseProvider);
    final slip = txn.slipId == null ? null : await slipRepo.get(txn.slipId!);
    if (!mounted) return;
    final pick = await showCategoryPicker(
      context,
      slip: slip,
      onTransfer: () => txnRepo.reclassifyAsTransfer(txn.id),
    );
    if (pick != null) {
      await txnRepo.setCategory(txn.id, pick.categoryId);
      if (pick.tagIds.isNotEmpty) {
        await db.setTransactionTags(txn.id, pick.tagIds);
      }
    }
  }

  Future<void> _deleteTxn(TransactionRow txn) async {
    await ref.read(transactionRepositoryProvider).delete(txn.id);
    if (mounted) _snack(AppLocalizations.of(context).txnDeleted);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _permissionDialog() async {
    // Once per process: the dialog fires on every cold launch while access is
    // denied, but revisiting Home in the same session only keeps the banner.
    if (ref.read(permDialogShownProvider)) return;
    ref.read(permDialogShownProvider.notifier).mark();
    // Captured before the awaits so a mid-dialog unmount can't break reads.
    final importer = ref.read(slipImporterProvider);
    final grant = await showPhotoPermissionDialog(context);
    if (!mounted) return;
    if (grant) {
      // Re-request first — on a fresh deny the OS prompt can still appear.
      // After "don't ask again" it resolves denied instantly → settings page.
      final perm = await importer.requestPermission();
      if (!perm.granted) await importer.openSettings();
    }
    if (!mounted) return;
    final notifier = ref.read(photoPermissionProvider.notifier);
    await notifier.refresh();
    if (!mounted) return;
    if (ref.read(photoPermissionProvider) == PhotoPermStatus.granted) {
      ref.read(scanControllerProvider.notifier).scan();
    }
  }
}

/// Pull-to-refresh hint shown while dragging (before the scan starts).
class _PullHint extends StatelessWidget {
  const _PullHint({required this.armed});
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              child: const Icon(
                AppIcons.arrowDown,
                size: 16,
                color: AppColors.terra,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              armed ? l10n.homePullRelease : l10n.homePullHint,
              style: AppTypography.body(
                size: 13.5,
                color: context.palette.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder dashboard shown on the first login of a new device while the
/// user's data is still being pulled from the cloud — mirrors the real layout
/// (spending card, income/expense chips, recent rows) so the switch to live
/// data is seamless.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Skeleton(height: 170, radius: 24),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Skeleton(height: 76, radius: 18)),
            SizedBox(width: 12),
            Expanded(child: Skeleton(height: 76, radius: 18)),
          ],
        ),
        const SizedBox(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Skeleton(width: 120, height: 16),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          const Skeleton(height: 58, radius: 16),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.homeGreetingMorning
        : (hour < 17 ? l10n.homeGreetingAfternoon : l10n.homeGreetingEvening);
    final name = ref.watch(appSettingsProvider).value?.displayName ??
        l10n.homeDefaultName;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTypography.body(
                  size: 13,
                  color: context.palette.ink3,
                ),
              ),
              Text(
                name,
                style: AppTypography.heading(size: 20, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        KeyedSubtree(
          key: HomeTourKeys.wallet,
          child: _WalletButton(onTap: () => showAccountsSheet(context)),
        ),
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
          color: context.palette.terraWash,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Icon(AppIcons.wallet, size: 22, color: context.palette.terraFg),
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
    this.blurNumbers = false,
  });

  final int spentCents;
  final int budgetCents;
  final String subtitleNoun;
  final bool scanning;
  final int? lastReadAt;
  final Future<void> Function() onRefresh;

  /// Blur the money figures while the first cloud pull is loading them.
  final bool blurNumbers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasBudget = budgetCents > 0;
    final remaining = budgetCents - spentCents;
    final progress =
        hasBudget ? (spentCents / budgetCents).clamp(0.0, 1.0) : 0.0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Same brand gradient as the profile banner, for a cohesive look.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.terra, AppColors.terra700],
        ),
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
              Text(
                l10n.homeSpentNoun(subtitleNoun),
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.reverse.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 2),
              SyncBlur(
                active: blurNumbers,
                child: Text(
                  Money.compact(spentCents),
                  style: AppTypography.heading(
                    size: 38,
                    weight: FontWeight.w600,
                    color: AppColors.reverse,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SyncBlur(
                active: blurNumbers,
                child: Text(
                  hasBudget
                      ? l10n.homeBudgetRemaining(
                          Money.compact(remaining),
                          Money.compact(budgetCents),
                        )
                      : l10n.homeNoBudget,
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.reverse.withValues(alpha: 0.82),
                  ),
                ),
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
                    Icon(
                      scanning ? AppIcons.loader : AppIcons.receiptText,
                      size: 14,
                      color: AppColors.reverse,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        scanning
                            ? l10n.homeReadingSlip
                            : l10n.homeLastReadSlip(
                                _relative(lastReadAt, l10n),
                              ),
                        style: AppTypography.body(
                          size: 12,
                          color: AppColors.reverse.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                    if (!scanning)
                      Icon(
                        AppIcons.rotateCw,
                        size: 14,
                        color: AppColors.reverse.withValues(alpha: 0.7),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relative(int? ms, AppLocalizations l10n) {
    if (ms == null) return l10n.homeNeverRead;
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (diff.inMinutes < 1) return l10n.homeJustNow;
    if (diff.inMinutes < 60) return l10n.homeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.homeHoursAgo(diff.inHours);
    return l10n.homeDaysAgo(diff.inDays);
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.homeRecentTitle,
          style: AppTypography.heading(size: 16, weight: FontWeight.w500),
        ),
        InkWell(
          onTap: onSeeAll,
          child: Text(
            l10n.homeSeeAll,
            style: AppTypography.heading(
              size: 13,
              weight: FontWeight.w400,
              color: AppColors.terra,
            ),
          ),
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
    required this.onShowSlip,
    required this.onDelete,
  });

  final List<TransactionRow> uncategorized;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final String locale;
  final void Function(String id) onTapTxn;
  final void Function(TransactionRow) onCategorize;
  final void Function(TransactionRow) onShowSlip;
  final Future<void> Function(TransactionRow) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (uncategorized.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const BunAvatar(size: 72),
            const SizedBox(height: 12),
            Text(
              l10n.homeNothingToCategorize,
              style: AppTypography.heading(size: 15, weight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.homeNothingToCategorizeHint,
              style: AppTypography.body(size: 13, color: context.palette.ink3),
            ),
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
        for (var i = 0; i < days.length; i++)
          TxnDayGroup(
            day: days[i],
            rows: byDay[days[i]]!,
            categories: categories,
            accounts: accounts,
            locale: locale,
            onTapTxn: onTapTxn,
            onCategorize: onCategorize,
            onShowSlip: onShowSlip,
            onDelete: onDelete,
            // Walkthrough anchor on the very first slip row.
            firstRowKey: i == 0 ? HomeTourKeys.slipRow : null,
          ),
      ],
    );
  }
}
