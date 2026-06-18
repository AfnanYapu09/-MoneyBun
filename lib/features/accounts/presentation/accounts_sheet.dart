import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';

/// Bottom sheet listing accounts MoneyBun watches for slips, with per-account
/// checkboxes + select-all. Toggling persists `watchedForSlips`.
class AccountsSheet extends ConsumerWidget {
  const AccountsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];
    final repo = ref.read(accountRepositoryProvider);
    final watchedCount = accounts.where((a) => a.watchedForSlips).length;
    final allOn = accounts.isNotEmpty && watchedCount == accounts.length;

    return SheetScaffold(
      title: 'บัญชีที่ให้น้องบันสแกนสลิป',
      footer: PrimaryButton(
        label: watchedCount > 0 ? 'บันทึก · $watchedCount บัญชี' : 'บันทึก',
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        children: [
          _Row(
            icon: AppIcons.wallet,
            iconBg: AppColors.terraWash,
            iconFg: AppColors.terra700,
            name: 'บัญชีทั้งหมด',
            on: allOn,
            onToggle: () {
              for (final a in accounts) {
                repo.setWatched(a.id, !allOn);
              }
            },
          ),
          const Divider(height: 12),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text('เลือกดูรายการจากบัญชี…',
                style: AppTypography.heading(
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: AppColors.ink3)),
          ),
          for (final a in accounts)
            _Row(
              icon: CategoryIcons.forKey(a.iconKey),
              iconBg: a.colorHex == null
                  ? AppColors.terra
                  : AppColors.forHex(a.colorHex!),
              iconFg: Colors.white,
              name: a.name,
              sub: a.bankCode == null ? null : _accountSub(a),
              on: a.watchedForSlips,
              onToggle: () => repo.setWatched(a.id, !a.watchedForSlips),
            ),
        ],
      ),
    );
  }

  String? _accountSub(AccountRow a) =>
      a.type.name == 'bank' ? 'ออมทรัพย์' : null;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.name,
    required this.on,
    required this.onToggle,
    this.sub,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String name;
  final String? sub;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.body(size: 15)),
                  if (sub != null)
                    Text(sub!,
                        style: AppTypography.body(
                            size: 12, color: AppColors.ink3)),
                ],
              ),
            ),
            _Check(on: on),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: on ? AppColors.terra : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: on ? null : Border.all(color: AppColors.line, width: 1.5),
      ),
      child:
          on ? const Icon(AppIcons.check, size: 15, color: Colors.white) : null,
    );
  }
}
