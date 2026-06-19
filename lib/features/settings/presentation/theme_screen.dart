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
    'FF2A6FDB',
    'FF8A5BD6',
    'FFC9A227',
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
              style: AppTypography.heading(
                  size: 14, weight: FontWeight.w500, color: AppColors.ink3)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in _modes) ...[
                Expanded(
                  child: _ModeSwatch(
                    mode: m.$1,
                    label: m.$2,
                    selected: mode == m.$1,
                    onTap: () => repo.setThemeMode(m.$1),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text('สีหลัก',
              style: AppTypography.heading(
                  size: 14, weight: FontWeight.w500, color: AppColors.ink3)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final a in _accents) ...[
                InkWell(
                  onTap: () => repo.setAccentColor(a),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.forHex(a),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: accent == a
                        ? const Icon(AppIcons.check,
                            size: 20, color: Colors.white)
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

/// A visual theme-mode preview card (light / dark / gradient) with a label.
class _ModeSwatch extends StatelessWidget {
  const _ModeSwatch({
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = mode == 'dark';
    final isSystem = mode == 'system';
    final bg = mode == 'light' ? AppColors.cream : AppColors.ink;
    final fg = mode == 'light'
        ? AppColors.ink
        : (isSystem ? AppColors.terra : AppColors.cream);
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              padding: const EdgeInsets.all(10),
              alignment: Alignment.bottomLeft,
              decoration: BoxDecoration(
                color: isSystem ? null : bg,
                gradient: isSystem
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.cream, AppColors.ink],
                        stops: [0.5, 0.5],
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.terra : AppColors.line,
                  width: 2,
                ),
              ),
              child: FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        (isDark ? AppColors.cream : fg).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: AppTypography.body(
                size: 13,
                color: selected ? AppColors.terra700 : AppColors.ink2)),
      ],
    );
  }
}
