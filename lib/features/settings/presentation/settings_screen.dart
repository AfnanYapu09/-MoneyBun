import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../data/repositories/settings_repository.dart';

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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Text('ตั้งค่า',
                style:
                    AppTypography.heading(size: 22, weight: FontWeight.w600)),
            const SizedBox(height: 16),
            // Profile card
            _ProfileCard(
              name: user?.displayName ?? settings.displayName,
              username: settings.username,
              onTap: () => context.push('/settings/profile'),
            ),
            const SizedBox(height: 18),
            const SettingSectionLabel('บัญชี'),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.userRound,
                label: 'โปรไฟล์ของฉัน',
                onTap: () => context.push('/settings/profile'),
              ),
              SettingRow(
                icon: AppIcons.banknote,
                label: 'สกุลเงิน',
                value: currencyLabel,
                onTap: () => context.push('/settings/currency'),
              ),
              SettingRow(
                icon: AppIcons.target,
                label: 'เป้าหมายการออม',
                onTap: () => context.push('/settings/savings'),
              ),
            ]),
            const SizedBox(height: 18),
            const SettingSectionLabel('จัดการข้อมูล'),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.layoutGrid,
                label: 'จัดการหมวดหมู่',
                onTap: () => context.push('/settings/categories'),
              ),
              SettingRow(
                icon: AppIcons.hash,
                label: 'จัดการแท็ก',
                onTap: () => context.push('/settings/tags'),
              ),
            ]),
            const SizedBox(height: 18),
            const SettingSectionLabel('ทั่วไป'),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.palette,
                label: 'ธีม',
                value: _themeLabel(settings.themeMode),
                onTap: () => context.push('/settings/theme'),
              ),
              SettingRow(
                icon: AppIcons.globe,
                label: 'ภาษา',
                value: settings.locale == 'th' ? 'ไทย' : 'English',
                onTap: () =>
                    repo.setLocale(settings.locale == 'th' ? 'en' : 'th'),
              ),
              SettingRow(
                icon: AppIcons.shieldCheck,
                label: 'ความปลอดภัย',
                onTap: () => context.push('/settings/security'),
              ),
              SettingRow(
                icon: AppIcons.circleHelp,
                label: 'ช่วยเหลือ',
                onTap: () => context.push('/settings/help'),
              ),
            ]),
            const SizedBox(height: 18),
            const SettingSectionLabel('สลิป & คลาวด์'),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.scanLine,
                label: 'ใช้ API ตรวจสลิปออนไลน์',
                trailing: Switch(
                  value: settings.slipApiEnabled,
                  onChanged: (v) => repo.setSlipApiEnabled(v),
                ),
              ),
              if (firebaseReady && user == null)
                SettingRow(
                  icon: AppIcons.google,
                  label: 'เข้าสู่ระบบเพื่อซิงค์',
                  onTap: () => context.push('/login'),
                ),
              if (firebaseReady && user != null)
                SettingRow(
                  icon: AppIcons.rotateCw,
                  label: 'ซิงค์ตอนนี้',
                  onTap: () => ref.read(syncEngineProvider)?.sync(),
                ),
              if (!firebaseReady)
                SettingRow(
                  icon: AppIcons.info,
                  label: 'ซิงค์คลาวด์ (ยังไม่ตั้งค่า Firebase)',
                  showChevron: false,
                ),
            ]),
            const SizedBox(height: 18),
            SettingGroup(children: [
              SettingRow(
                icon: AppIcons.logOut,
                label: 'ออกจากระบบ',
                danger: true,
                showChevron: false,
                onTap: () => _logout(context, ref),
              ),
            ]),
            const SizedBox(height: 20),
            Center(
              child: Text('MoneyBun v0.1.0',
                  style: AppTypography.body(size: 12, color: AppColors.ink3)),
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(String mode) => switch (mode) {
        'light' => 'สว่าง',
        'dark' => 'มืด',
        _ => 'อัตโนมัติ',
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
    required this.onTap,
  });
  final String name;
  final String username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.terra,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const BunAvatar(size: 36),
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
                  Text('@$username · สมาชิกฟรี',
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
