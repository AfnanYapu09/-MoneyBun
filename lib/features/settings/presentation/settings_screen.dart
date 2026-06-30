import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final repo = ref.read(settingsRepositoryProvider);
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final user = ref.watch(authStateProvider).value;
    final currencyLabel = settings.currencyCode;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Text(l10n.settings,
                style:
                    AppTypography.heading(size: 22, weight: FontWeight.w600)),
            const SizedBox(height: 16),
            // Profile card
            _ProfileCard(
              name: user?.displayName ?? settings.displayName,
              username: settings.username,
              avatarPath: settings.avatarPath,
              onTap: () => context.push('/settings/profile'),
            ),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsAccountSection),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.userRound,
                label: l10n.settingsMyProfile,
                onTap: () => context.push('/settings/profile'),
              ),
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
            ]),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsDataSection),
            SettingGroup(children: [
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
            ]),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsGeneralSection),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.palette,
                label: l10n.settingsTheme,
                value: _themeLabel(settings.themeMode, l10n),
                onTap: () => context.push('/settings/theme'),
              ),
              SettingRow(
                icon: AppIcons.globe,
                label: l10n.language,
                value: settings.locale == 'th' ? l10n.langThai : l10n.langEnglish,
                onTap: () =>
                    repo.setLocale(settings.locale == 'th' ? 'en' : 'th'),
              ),
              SettingRow(
                icon: AppIcons.download,
                label: l10n.settingsExportData,
                onTap: () => context.push('/settings/export'),
              ),
              SettingRow(
                icon: AppIcons.circleHelp,
                label: l10n.settingsHelp,
                onTap: () => context.push('/settings/help'),
              ),
            ]),
            const SizedBox(height: 18),
            SettingSectionLabel(l10n.settingsCloudSection),
            SettingGroup(children: [
              if (firebaseReady && user == null)
                SettingRow(
                  icon: AppIcons.google,
                  label: l10n.settingsSignInToSync,
                  onTap: () => context.push('/login'),
                ),
              if (firebaseReady && user != null)
                SettingRow(
                  icon: AppIcons.rotateCw,
                  label: l10n.syncNow,
                  onTap: () => ref.read(syncEngineProvider)?.sync(),
                ),
              if (!firebaseReady)
                SettingRow(
                  icon: AppIcons.info,
                  label: l10n.settingsCloudNotConfigured,
                  showChevron: false,
                ),
            ]),
            const SizedBox(height: 18),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.logOut,
                label: l10n.signOut,
                danger: true,
                showChevron: false,
                onTap: () => _logout(context, ref),
              ),
            ]),
            const SizedBox(height: 20),
            Center(
              child: Text('moneyBun v1.0.0',
                  style: AppTypography.body(
                      size: 12, color: context.palette.ink3)),
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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmLogout(context);
    if (!ok) return;
    await ref.read(authServiceProvider)?.signOut();
    await ref.read(settingsRepositoryProvider).setAuthMode('guest');
    if (context.mounted) context.go('/login');
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.username,
    required this.avatarPath,
    required this.onTap,
  });
  final String name;
  final String username;
  final String? avatarPath;
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
          color: AppColors.terra,
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
                  Text(name,
                      style: AppTypography.heading(
                          size: 18,
                          weight: FontWeight.w600,
                          color: AppColors.reverse)),
                  Text(l10n.settingsHandleFreeMember(username),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.reverse.withValues(alpha: 0.85))),
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
