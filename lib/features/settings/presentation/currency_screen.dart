import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';

class CurrencyScreen extends ConsumerWidget {
  const CurrencyScreen({super.key});

  static const _currencies = [
    ('THB', '฿'),
    ('USD', r'$'),
    ('EUR', '€'),
    ('JPY', '¥'),
    ('GBP', '£'),
  ];

  String _currencyName(String code, AppLocalizations l10n) => switch (code) {
        'THB' => l10n.settingsCurrencyTHB,
        'USD' => l10n.settingsCurrencyUSD,
        'EUR' => l10n.settingsCurrencyEUR,
        'JPY' => l10n.settingsCurrencyJPY,
        'GBP' => l10n.settingsCurrencyGBP,
        _ => code,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).value?.currencyCode ?? 'THB';
    final repo = ref.read(settingsRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    return SubScreenScaffold(
      title: l10n.settingsCurrency,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          SettingGroup(
            children: [
              for (final c in _currencies)
                SelectRow(
                  leading: SizedBox(
                    width: 26,
                    child: Text(
                      c.$2,
                      textAlign: TextAlign.center,
                      style: AppTypography.heading(
                        size: 18,
                        weight: FontWeight.w600,
                        color: context.palette.terraFg,
                      ),
                    ),
                  ),
                  label: _currencyName(c.$1, l10n),
                  secondary: c.$1,
                  selected: current == c.$1,
                  onTap: () => repo.setCurrency(c.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.settingsCurrencyDisplayNote,
            style: AppTypography.body(size: 12.5, color: context.palette.ink3),
          ),
        ],
      ),
    );
  }
}
