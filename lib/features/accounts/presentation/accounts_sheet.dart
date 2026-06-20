import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';

/// Bottom sheet to choose which banks' gallery albums น้องบัน scans for slips.
/// Each toggle persists `watchedForSlips` immediately (no Save button); the slip
/// importer skips the albums of banks turned off here.
class AccountsSheet extends ConsumerStatefulWidget {
  const AccountsSheet({super.key});

  @override
  ConsumerState<AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends ConsumerState<AccountsSheet> {
  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];
    final repo = ref.read(accountRepositoryProvider);
    // Only bank / e-wallet accounts have a slip album to scan (cash has none).
    final banks = accounts.where((a) => a.bankCode != null).toList();
    final watchedCount = banks.where((a) => a.watchedForSlips).length;
    final allOn = banks.isNotEmpty && watchedCount == banks.length;

    return SheetScaffold(
      title: 'บัญชีที่ให้น้องบันสแกนสลิป',
      action: TextButton(
        onPressed: () {
          for (final a in banks) {
            repo.setWatched(a.id, true);
          }
        },
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
          _Row(
            icon: AppIcons.wallet,
            iconBg: AppColors.terraWash,
            iconFg: AppColors.terra700,
            name: 'ทุกธนาคาร',
            on: allOn,
            onToggle: () {
              for (final a in banks) {
                repo.setWatched(a.id, !allOn);
              }
            },
          ),
          const Divider(height: 14),
          if (banks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('ยังไม่มีบัญชีธนาคาร',
                    style:
                        AppTypography.body(size: 13.5, color: AppColors.ink3)),
              ),
            ),
          for (final a in banks)
            _Row(
              icon: CategoryIcons.forKey(a.iconKey),
              iconBg: a.colorHex == null
                  ? AppColors.terra
                  : AppColors.forHex(a.colorHex!),
              iconFg: Colors.white,
              name: a.name,
              on: a.watchedForSlips,
              onToggle: () => repo.setWatched(a.id, !a.watchedForSlips),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.name,
    required this.on,
    required this.onToggle,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String name;
  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: iconFg),
            ),
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
