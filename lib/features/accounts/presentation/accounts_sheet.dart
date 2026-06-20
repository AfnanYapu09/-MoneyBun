import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/constants/bank_catalog.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/bank_logo.dart';
import '../../../core/widgets/sheet_scaffold.dart';

/// Bottom sheet to choose which banks' gallery albums น้องบัน scans for slips.
/// Each toggle persists immediately to settings (no Save button); the slip
/// importer skips the albums of banks turned off here.
class AccountsSheet extends ConsumerWidget {
  const AccountsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final disabled = settings?.disabledScanIds ?? const <String>{};
    final repo = ref.read(settingsRepositoryProvider);
    final allOn = disabled.isEmpty;

    void setAll(bool on) {
      final ids = on ? <String>{} : {for (final b in BankCatalog.all) b.id};
      repo.setDisabledScanIds(ids);
    }

    void toggle(String id) {
      final next = disabled.toSet();
      if (!next.add(id)) next.remove(id); // already disabled → re-enable
      repo.setDisabledScanIds(next);
    }

    return SheetScaffold(
      title: 'บัญชีที่ให้น้องบันสแกนสลิป',
      action: TextButton(
        onPressed: () => setAll(true),
        child: Text('รีเซ็ต',
            style: AppTypography.heading(
                size: 14, weight: FontWeight.w500, color: AppColors.terra)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('ปิดธนาคารที่ไม่ต้องการให้อ่านสลิปจากอัลบั้ม',
                style: AppTypography.body(size: 13.5, color: AppColors.ink3)),
          ),
          _ToggleRow(
            leading: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.terraWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.wallet,
                  size: 20, color: AppColors.terra700),
            ),
            name: 'ทุกธนาคาร',
            on: allOn,
            onTap: () => setAll(!allOn),
          ),
          const Divider(height: 14),
          for (final bank in BankCatalog.all)
            _ToggleRow(
              leading: BankLogo(bank: bank),
              name: bank.nameTh,
              on: !disabled.contains(bank.id),
              onTap: () => toggle(bank.id),
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.leading,
    required this.name,
    required this.on,
    required this.onTap,
  });

  final Widget leading;
  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Text(name, style: AppTypography.body(size: 15)),
            ),
            // Display-only: the whole row's InkWell handles the tap.
            AppToggle(value: on),
          ],
        ),
      ),
    );
  }
}
