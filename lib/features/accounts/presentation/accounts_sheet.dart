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
import '../../../l10n/generated/app_localizations.dart';

/// Bottom sheet to choose which banks' gallery albums น้องบัน scans for slips.
/// Each toggle persists immediately to settings (no Save button); the slip
/// importer skips the albums of banks turned off here.
class AccountsSheet extends ConsumerStatefulWidget {
  const AccountsSheet({super.key});

  @override
  ConsumerState<AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends ConsumerState<AccountsSheet> {
  /// Local working copy of the disabled set. Each tap composes on top of the
  /// previous one — computing from the (async) settings stream instead made
  /// two quick taps read the same stale snapshot, so the second undid the
  /// first, and a tap on the very first frame (settings still null) wiped
  /// every saved toggle.
  Set<String>? _disabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    _disabled ??= settings?.disabledScanIds.toSet();
    final disabled = _disabled ?? const <String>{};
    final ready = _disabled != null;
    final repo = ref.read(settingsRepositoryProvider);
    final allOn = disabled.isEmpty;

    void setAll(bool on) {
      if (!ready) return;
      final ids = on ? <String>{} : {for (final b in BankCatalog.all) b.id};
      setState(() => _disabled = ids);
      repo.setDisabledScanIds(ids);
    }

    void toggle(String id) {
      if (!ready) return;
      final next = disabled.toSet();
      if (!next.add(id)) next.remove(id); // already disabled → re-enable
      setState(() => _disabled = next);
      repo.setDisabledScanIds(next);
    }

    return SheetScaffold(
      title: l10n.acctScanTitle,
      action: TextButton(
        onPressed: () => setAll(true),
        child: Text(
          l10n.acctReset,
          style: AppTypography.heading(
            size: 14,
            weight: FontWeight.w500,
            color: AppColors.terra,
          ),
        ),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.acctScanDesc,
              style: AppTypography.body(
                size: 13.5,
                color: context.palette.ink3,
              ),
            ),
          ),
          _ToggleRow(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.palette.terraWash,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.wallet,
                size: 20,
                color: context.palette.terraFg,
              ),
            ),
            name: l10n.acctAllBanks,
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
            Expanded(child: Text(name, style: AppTypography.body(size: 15))),
            // Display-only: the whole row's InkWell handles the tap.
            AppToggle(value: on),
          ],
        ),
      ),
    );
  }
}
