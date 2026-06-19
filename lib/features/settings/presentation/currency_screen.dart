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
    ('USD', r'$', 'ดอลลาร์สหรัฐ'),
    ('EUR', '€', 'ยูโร'),
    ('JPY', '¥', 'เยนญี่ปุ่น'),
    ('GBP', '£', 'ปอนด์'),
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
                leading: SizedBox(
                  width: 26,
                  child: Text(c.$2,
                      textAlign: TextAlign.center,
                      style: AppTypography.heading(
                          size: 18,
                          weight: FontWeight.w600,
                          color: AppColors.terra700)),
                ),
                label: c.$3,
                secondary: c.$1,
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
