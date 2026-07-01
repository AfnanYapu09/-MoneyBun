import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  static const _modes = ['light', 'dark', 'system'];

  String _modeLabel(String mode, AppLocalizations l10n) => switch (mode) {
        'light' => l10n.settingsThemeLight,
        'dark' => l10n.settingsThemeDark,
        _ => l10n.settingsThemeSystem,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final mode = settings?.themeMode ?? 'system';
    final repo = ref.read(settingsRepositoryProvider);
    final l10n = AppLocalizations.of(context);

    return SubScreenScaffold(
      title: l10n.settingsTheme,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            l10n.settingsDisplayMode,
            style: AppTypography.heading(
              size: 14,
              weight: FontWeight.w500,
              color: context.palette.ink3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in _modes) ...[
                Expanded(
                  child: _ModeSwatch(
                    mode: m,
                    label: _modeLabel(m, l10n),
                    selected: mode == m,
                    onTap: () => repo.setThemeMode(m),
                  ),
                ),
                const SizedBox(width: 12),
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
                  color: selected ? AppColors.terra : context.palette.line,
                  width: 2,
                ),
              ),
              child: FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.cream : fg).withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.body(
            size: 13,
            color: selected ? context.palette.terraFg : context.palette.ink2,
          ),
        ),
      ],
    );
  }
}
