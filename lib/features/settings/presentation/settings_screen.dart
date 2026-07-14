import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../plan/domain/plan.dart';
import '../../plan/domain/quota_period.dart';
import '../../../l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Single-flight guard: the logout flow awaits network + dialogs, so a
  /// second tap on "ออกจากระบบ" must not start a parallel wipe.
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final repo = ref.read(settingsRepositoryProvider);
    final currencyLabel = settings.currencyCode;
    final l10n = AppLocalizations.of(context);
    final packageInfo = ref.watch(packageInfoProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Text(
              l10n.settings,
              style: AppTypography.heading(size: 22, weight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // Profile card
            _ProfileCard(
              // Show the locally-editable name so edits in the profile screen
              // are always reflected here (the Firebase displayName, when set,
              // is seeded into settings at sign-up).
              name: settings.displayName,
              username: settings.username,
              avatarPath: settings.avatarPath,
              tier: ref.watch(planProvider).tier,
              onTap: () => context.push('/settings/profile'),
            ),
            const SizedBox(height: 10),
            // This cycle's scan quota at a glance — taps through to the plans.
            _QuotaBar(
              membership: ref.watch(membershipProvider).value ??
                  Membership.fallback(DateTime.now()),
              locale: settings.locale,
              onTap: () => context.push('/settings/plan'),
            ),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsAccountSection),
            SettingGroup(
              children: [
                SettingRow(
                  icon: AppIcons.userRound,
                  label: l10n.settingsMyProfile,
                  onTap: () => context.push('/settings/profile'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsMoneySection),
            SettingGroup(
              children: [
                SettingRow(
                  icon: AppIcons.banknote,
                  label: l10n.settingsCurrency,
                  value: currencyLabel,
                  onTap: () => context.push('/settings/currency'),
                ),
                SettingRow(
                  icon: AppIcons.target,
                  label: l10n.settingsSavingsGoal,
                  onTap: () => context.push('/settings/savings'),
                ),
                SettingRow(
                  icon: AppIcons.layoutGrid,
                  label: l10n.manageCategories,
                  onTap: () => context.push('/settings/categories'),
                ),
                SettingRow(
                  icon: AppIcons.hash,
                  label: l10n.settingsManageTags,
                  onTap: () => context.push('/settings/tags'),
                ),
                SettingRow(
                  icon: AppIcons.repeat,
                  label: l10n.settingsRecurring,
                  onTap: () => context.push('/settings/recurring'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsGeneralSection),
            SettingGroup(
              children: [
                SettingRow(
                  icon: AppIcons.palette,
                  label: l10n.settingsTheme,
                  value: _themeLabel(settings.themeMode, l10n),
                  onTap: () => context.push('/settings/theme'),
                ),
                SettingRow(
                  icon: AppIcons.globe,
                  label: l10n.language,
                  value: settings.locale == 'th'
                      ? l10n.langThai
                      : l10n.langEnglish,
                  onTap: () =>
                      repo.setLocale(settings.locale == 'th' ? 'en' : 'th'),
                ),
                SettingRow(
                  icon: AppIcons.bellRing,
                  label: l10n.settingsReminder,
                  value: settings.reminderEnabled
                      ? settings.reminderTime
                      : l10n.reminderOff,
                  onTap: () => context.push('/settings/reminder'),
                ),
                SettingRow(
                  icon: AppIcons.download,
                  label: l10n.settingsExportData,
                  onTap: () => context.push('/settings/export'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsSupportSection),
            SettingGroup(
              children: [
                SettingRow(
                  icon: AppIcons.sparkles,
                  label: l10n.settingsShowTour,
                  onTap: () {
                    // Jump to Home and replay the walkthrough there.
                    ref.read(tourReplayProvider.notifier).request();
                    context.go('/home');
                  },
                ),
                SettingRow(
                  icon: AppIcons.circleHelp,
                  label: l10n.settingsHelp,
                  onTap: () => context.push('/settings/help'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingGroup(
              children: [
                SettingRow(
                  icon: AppIcons.logOut,
                  label: l10n.signOut,
                  danger: true,
                  showChevron: false,
                  onTap: _logout,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    packageInfo == null
                        ? 'moneyBun'
                        : 'moneyBun v${packageInfo.version}'
                            ' (${packageInfo.buildNumber})',
                    style: AppTypography.body(
                      size: 12,
                      color: context.palette.ink3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'พัฒนาโดย Afnan_YP',
                    style: AppTypography.body(
                      size: 12,
                      color: context.palette.ink3,
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

  String _themeLabel(String mode, AppLocalizations l10n) => switch (mode) {
        'light' => l10n.settingsThemeLight,
        'dark' => l10n.settingsThemeDark,
        _ => l10n.settingsThemeSystem,
      };

  Future<void> _logout() async {
    if (_loggingOut) return;
    final context = this.context;
    final ok = await confirmLogout(context);
    if (!ok) return;
    // Capture the app-lifetime singletons BEFORE signing out: the auth-state
    // redirect disposes this screen the instant Firebase emits null, after which
    // ref.read would throw and the wipe would be skipped. These providers are
    // never auto-disposed, so the instances outlive the widget.
    final auth = ref.read(authServiceProvider);
    final engine = ref.read(syncEngineProvider);
    final db = ref.read(databaseProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final gen = ref.read(sessionGenerationProvider);
    _loggingOut = true;
    try {
      // Upload anything still pending before the wipe below destroys it —
      // recent edits sit behind a 3s push debounce, so "confirm logout right
      // after an edit" would otherwise lose that edit. Bounded so a dead
      // network can't hang the logout.
      if (engine != null) {
        try {
          await engine.flushPending(timeout: const Duration(seconds: 10));
        } catch (_) {}
        // Rows that STILL aren't synced (offline, upload failed) are about to
        // be deleted for good — that decision belongs to the user, not us.
        if (await db.hasPendingRows()) {
          if (!context.mounted) return;
          final discard = await confirmLogoutUnsynced(context);
          if (!discard) return;
        }
      }
      // Sign out first so the sync engine (which keys off the current user)
      // goes idle — its in-flight pulls/pushes check the uid before every
      // local write, so nothing of the old account lands after the wipe.
      try {
        await auth?.signOut();
      } finally {
        // Even if signOut throws, never leave the old account's data behind
        // for the next sign-in to see. Bump the session generation FIRST so
        // any still-in-flight sync or post-sync callback aborts its writes
        // instead of re-planting the old account's rows/watermarks/avatar
        // into the freshly wiped database.
        gen.bump();
        await db.clearAllData();
        await settingsRepo.resetUserData();
      }
      if (context.mounted) context.go('/login');
    } finally {
      _loggingOut = false;
    }
  }
}

/// Compact scan-quota meter under the profile card: the current cycle's free
/// usage "X/30" (plus a credits chip when the account holds any) with a
/// progress bar that warms up as the free allowance fills, and the cycle's
/// reset date. Taps through to the plan screen.
class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.membership,
    required this.locale,
    required this.onTap,
  });

  final Membership membership;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unlimited = membership.unlimited;
    final used = membership.freeUsed;
    const cap = QuotaPeriod.freePerPeriod;
    final shownUsed = used > cap ? cap : used;
    final credits = membership.creditBalance;
    final ratio = unlimited ? 0.0 : (used / cap).clamp(0.0, 1.0).toDouble();
    // With credits in reserve a filling bar isn't alarming — keep it
    // terracotta; warn only when the free cycle is all that's left.
    final barColor = ratio >= 1 && credits == 0
        ? context.palette.dangerFg
        : (ratio >= 0.8 && credits == 0 ? AppColors.amber : AppColors.terra);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.receipt,
                  size: 15,
                  color: context.palette.terraFg,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.settingsQuotaTitle,
                    style: AppTypography.body(
                      size: 13,
                      color: context.palette.ink2,
                    ),
                  ),
                ),
                if (!unlimited && credits > 0) ...[
                  Text(
                    l10n.settingsQuotaCredits(credits),
                    style: AppTypography.heading(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: context.palette.terraFg,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  unlimited
                      ? '$used · ${l10n.settingsQuotaUnlimited}'
                      : '$shownUsed/$cap',
                  style: AppTypography.heading(
                    size: 13.5,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  AppIcons.chevronRight,
                  size: 15,
                  color: context.palette.ink3,
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: context.palette.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            if (!unlimited) ...[
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.settingsQuotaResetOn(
                    AppDate.formatDayShort(
                      membership.periodResetAt,
                      locale: locale,
                    ),
                  ),
                  style: AppTypography.body(
                    size: 11.5,
                    color: context.palette.ink3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.username,
    required this.avatarPath,
    required this.tier,
    required this.onTap,
  });
  final String name;
  final String username;
  final String? avatarPath;
  final PlanTier tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.terra, AppColors.terra700],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            ProfileAvatar(
              avatarPath: avatarPath,
              size: 56,
              radius: 16,
              bunSize: 40,
              bunBackground: AppColors.cream,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.heading(
                      size: 18,
                      weight: FontWeight.w600,
                      color: AppColors.reverse,
                    ),
                  ),
                  Text(
                    switch (tier) {
                      PlanTier.ultra =>
                        l10n.settingsHandleUltraMember(username),
                      PlanTier.pro => l10n.settingsHandleProMember(username),
                      PlanTier.free => l10n.settingsHandleFreeMember(username),
                    },
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.reverse.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.pencil, size: 20, color: AppColors.reverse),
          ],
        ),
      ),
    );
  }
}
