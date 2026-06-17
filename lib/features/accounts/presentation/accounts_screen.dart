import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/pixel_border.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final balances = ref.watch(accountBalancesProvider);
    final total = balances.values.fold<int>(0, (s, v) => s + v);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accounts),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _editAccount(context, ref, null),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          PixelBorder(
            color: AppColors.bunOrange,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.balance,
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w700)),
                Text(
                  Money.format(total),
                  style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final a in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PixelBorder(
                onTap: () => _editAccount(context, ref, a),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.forHex(a.colorHex ?? 'FFE8732C')
                            .withValues(alpha: 0.18),
                        border: Border.all(
                            color: AppColors.forHex(a.colorHex ?? 'FFE8732C'),
                            width: 2),
                      ),
                      child: Icon(CategoryIcons.forAccount(a.type),
                          color: AppColors.forHex(a.colorHex ?? 'FFE8732C')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(a.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text(
                      Money.format(balances[a.id] ?? 0),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: (balances[a.id] ?? 0) < 0
                            ? AppColors.expense
                            : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          PixelButton(
            label: l10n.quickTransfer,
            icon: Icons.swap_horiz,
            color: AppColors.transfer,
            expand: true,
            onPressed: () => context.push('/add?type=transfer'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAccount(
      BuildContext context, WidgetRef ref, AccountRow? account) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountEditor(account: account),
    );
  }
}

class _AccountEditor extends ConsumerStatefulWidget {
  const _AccountEditor({this.account});
  final AccountRow? account;

  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.account?.name ?? '');
  late final TextEditingController _opening = TextEditingController(
    text: widget.account == null
        ? ''
        : Money.toEditString(widget.account!.openingBalanceCents),
  );
  late AccountType _type = widget.account?.type ?? AccountType.cash;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.account != null;
    final typeLabels = {
      AccountType.cash: l10n.acctCash,
      AccountType.bank: l10n.acctBank,
      AccountType.ewallet: l10n.acctEwallet,
      AccountType.savings: l10n.acctSavings,
      AccountType.credit: l10n.acctCredit,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isEdit ? l10n.editAccount : l10n.addAccount,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.accountName),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: l10n.accountType),
            items: [
              for (final t in AccountType.values)
                DropdownMenuItem(value: t, child: Text(typeLabels[t]!)),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: l10n.openingBalance, prefixText: '฿ '),
          ),
          const SizedBox(height: 20),
          PixelButton(
            label: l10n.save,
            expand: true,
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              await ref.read(accountRepositoryProvider).save(
                    id: widget.account?.id,
                    name: _name.text.trim(),
                    type: _type,
                    openingBalanceCents: Money.parseToCents(_opening.text) ?? 0,
                    colorHex: widget.account?.colorHex,
                  );
              if (context.mounted) Navigator.pop(context);
            },
          ),
          if (isEdit && widget.account!.id != 'sys_cash') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref
                    .read(accountRepositoryProvider)
                    .delete(widget.account!.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(l10n.delete,
                  style: const TextStyle(color: AppColors.expense)),
            ),
          ],
        ],
      ),
    );
  }
}
