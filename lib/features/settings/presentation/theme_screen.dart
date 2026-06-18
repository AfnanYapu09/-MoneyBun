import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  static const _modes = [
    ('light', 'สว่าง'),
    ('dark', 'มืด'),
    ('system', 'อัตโนมัติ'),
  ];
  static const _accents = [
    'FFC4694A',
    'FF4E7A5E',
    'FF3D7DCA',
    'FF8A6DBF',
    'FFD9476B',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final mode = settings?.themeMode ?? 'system';
    final accent = settings?.accentColor ?? 'FFC4694A';
    final repo = ref.read(settingsRepositoryProvider);

    return SubScreenScaffold(
      title: 'ธีม',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('โหมดการแสดงผล',
              style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final m in _modes) ...[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => repo.setThemeMode(m.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              mode == m.$1 ? AppColors.terra : AppColors.line,
                          width: mode == m.$1 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            m.$1 == 'light'
                                ? Icons.light_mode_outlined
                                : m.$1 == 'dark'
                                    ? Icons.dark_mode_outlined
                                    : Icons.brightness_auto_outlined,
                            color:
                                mode == m.$1 ? AppColors.terra : AppColors.ink3,
                          ),
                          const SizedBox(height: 8),
                          Text(m.$2,
                              style: AppTypography.heading(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: mode == m.$1
                                      ? AppColors.terra
                                      : AppColors.ink2)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text('สีหลัก',
              style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final a in _accents) ...[
                InkWell(
                  onTap: () => repo.setAccentColor(a),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.forHex(a),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              accent == a ? AppColors.ink : Colors.transparent,
                          width: 2),
                    ),
                    child: accent == a
                        ? const Icon(AppIcons.check,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
