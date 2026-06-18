import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';

class CurrencyScreen extends ConsumerWidget {
  const CurrencyScreen({super.key});

  static const _currencies = [
    ('THB', '฿', 'บาทไทย'),
    ('USD', r'$', 'US Dollar'),
    ('EUR', '€', 'Euro'),
    ('JPY', '¥', 'Japanese Yen'),
    ('GBP', '£', 'British Pound'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).value?.currencyCode ?? 'THB';
    final repo = ref.read(settingsRepositoryProvider);
    return SubScreenScaffold(
      title: 'สกุลเงิน',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          SettingGroup(children: [
            for (final c in _currencies)
              SelectRow(
                label: '${c.$2}  ${c.$1} · ${c.$3}',
                selected: current == c.$1,
                onTap: () => repo.setCurrency(c.$1),
              ),
          ]),
          const SizedBox(height: 12),
          Text('ใช้สำหรับการแสดงผลเท่านั้น ยอดเงินยังบันทึกเป็นสตางค์',
              style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
        ],
      ),
    );
  }
}
