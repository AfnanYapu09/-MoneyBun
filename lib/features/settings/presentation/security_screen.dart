import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final repo = ref.read(settingsRepositoryProvider);

    return SubScreenScaffold(
      title: 'ความปลอดภัย',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.terraWash,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(AppIcons.shieldCheck,
                  size: 30, color: AppColors.terra700),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                'ล็อกแอปด้วย PIN หรือไบโอเมตริก เพื่อปกป้องข้อมูลการเงินของคุณ',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 13.5, color: AppColors.ink2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SettingSectionLabel('การล็อก'),
          SettingGroup(children: [
            SettingRow(
              icon: AppIcons.lockKeyhole,
              label: 'ล็อกด้วย PIN',
              toggleValue: settings?.pinEnabled ?? false,
              onToggle: (v) => _togglePin(context, ref, v),
            ),
            SettingRow(
              icon: AppIcons.scanFace,
              label: 'Face ID / ลายนิ้วมือ',
              toggleValue: settings?.biometricEnabled ?? false,
              onToggle: (v) => repo.setBiometricEnabled(v),
            ),
            SettingRow(
              icon: AppIcons.keyRound,
              label: 'เปลี่ยน PIN',
              onTap: () => _setPin(context, ref),
            ),
          ]),
          const SizedBox(height: 18),
          const SettingSectionLabel('ความเป็นส่วนตัว'),
          SettingGroup(children: [
            SettingRow(
              icon: AppIcons.eyeOff,
              label: 'ซ่อนยอดเงินในหน้าหลัก',
              toggleValue: settings?.hideBalance ?? false,
              onToggle: (v) => repo.setHideBalance(v),
            ),
            SettingRow(
              icon: AppIcons.download,
              label: 'ส่งออกข้อมูล (CSV)',
              onTap: () => _exportCsv(context, ref),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref, bool on) async {
    final repo = ref.read(settingsRepositoryProvider);
    if (on) {
      await _setPin(context, ref);
    } else {
      await repo.clearPin();
    }
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ตั้ง PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'PIN 4–6 หลัก'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(c, controller.text.trim()),
              child: const Text('บันทึก')),
        ],
      ),
    );
    if (pin != null && pin.length >= 4) {
      await ref.read(settingsRepositoryProvider).setPin(pin);
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final txns = await ref.read(transactionRepositoryProvider).watchAll().first;
    final buffer = StringBuffer('date,type,amount,note\n');
    for (final t in txns) {
      final date = AppDate.fromMillis(t.occurredAt).toIso8601String();
      final note = (t.note ?? '').replaceAll(',', ' ');
      buffer.writeln(
          '$date,${t.type.name},${Money.format(t.amountCents, symbol: false)},$note');
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/moneybun_export.csv');
      await file.writeAsString(buffer.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ส่งออกแล้ว: ${file.path}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ส่งออกไม่สำเร็จ')));
      }
    }
  }
}
