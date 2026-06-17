import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/pixel_theme.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/parsed_slip.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen(
      {super.key, this.id, this.prefill, this.initialType});

  final String? id;
  final ParsedSlip? prefill;
  final TxnType? initialType;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  TxnType _type = TxnType.expense;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  String? _slipId;
  ParsedSlip? _pendingSlip;
  bool _loading = true;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isEdit) {
      final row = await ref.read(transactionRepositoryProvider).get(widget.id!);
      if (row != null) {
        _type = row.type;
        _amount.text = Money.toEditString(row.amountCents);
        _note.text = row.note ?? '';
        _categoryId = row.categoryId;
        _accountId = row.accountId;
        _toAccountId = row.toAccountId;
        _occurredAt = AppDate.fromMillis(row.occurredAt);
        _slipId = row.slipId;
      }
    } else if (widget.prefill != null) {
      _applySlip(widget.prefill!);
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applySlip(ParsedSlip slip) {
    _pendingSlip = slip;
    _type = TxnType.expense;
    if (slip.amountCents != null) {
      _amount.text = Money.toEditString(slip.amountCents!);
    }
    if (slip.occurredAt != null) _occurredAt = slip.occurredAt!;
    final ref = slip.transRef;
    if (ref != null && _note.text.isEmpty) _note.text = 'Ref $ref';
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => _type == TxnType.income
            ? c.type == CategoryType.income
            : c.type == CategoryType.expense)
        .toList();

    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editTransaction : l10n.addTransaction),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _TypeSelector(
            value: _type,
            onChanged: (t) => setState(() {
              _type = t;
              if (t == TxnType.transfer) _categoryId = null;
            }),
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          _amountField(l10n),
          const SizedBox(height: 16),
          if (_type != TxnType.transfer) ...[
            Text(l10n.selectCategory,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _CategoryGrid(
              categories: categories,
              selectedId: _categoryId,
              onSelect: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 16),
          ],
          _accountPickers(l10n, accounts),
          const SizedBox(height: 16),
          _dateRow(l10n),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration:
                InputDecoration(labelText: l10n.note, hintText: l10n.noteHint),
          ),
          if (_type != TxnType.transfer) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _scanSlip,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.scanSlip),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(
                    color: AppColors.ink, width: PixelTokens.border),
                shape: const RoundedRectangleBorder(
                    borderRadius: PixelTokens.borderRadius),
              ),
            ),
          ],
          const SizedBox(height: 24),
          PixelButton(
              label: l10n.save, expand: true, onPressed: () => _save(l10n)),
        ],
      ),
    );
  }

  Widget _amountField(AppLocalizations l10n) {
    final color = switch (_type) {
      TxnType.income => AppColors.income,
      TxnType.expense => AppColors.expense,
      TxnType.transfer => AppColors.transfer,
    };
    return TextField(
      controller: _amount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: l10n.amount,
        prefixText: '฿ ',
        hintText: '0.00',
      ),
    );
  }

  Widget _accountPickers(AppLocalizations l10n, List<AccountRow> accounts) {
    return Column(
      children: [
        _accountDropdown(
          label: _type == TxnType.transfer ? l10n.fromAccount : l10n.account,
          value: _accountId,
          accounts: accounts,
          onChanged: (v) => setState(() => _accountId = v),
        ),
        if (_type == TxnType.transfer) ...[
          const SizedBox(height: 12),
          _accountDropdown(
            label: l10n.toAccount,
            value: _toAccountId,
            accounts: accounts.where((a) => a.id != _accountId).toList(),
            onChanged: (v) => setState(() => _toAccountId = v),
          ),
        ],
      ],
    );
  }

  Widget _accountDropdown({
    required String label,
    required String? value,
    required List<AccountRow> accounts,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: accounts.any((a) => a.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Row(
              children: [
                Icon(CategoryIcons.forAccount(a.type), size: 18),
                const SizedBox(width: 8),
                Text(a.name),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _dateRow(AppLocalizations l10n) {
    final locale = ref.watch(localeProvider).languageCode;
    return InkWell(
      onTap: _pickDateTime,
      child: InputDecorator(
        decoration: InputDecoration(labelText: l10n.dateTime),
        child: Row(
          children: [
            const Icon(Icons.event, size: 18, color: AppColors.gray500),
            const SizedBox(width: 8),
            Text(
              '${AppDate.formatDay(_occurredAt, locale: locale)}  ${AppDate.formatTime(_occurredAt, locale: locale)}',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  Future<void> _scanSlip() async {
    final result = await context.push<ParsedSlip>('/slip');
    if (result != null && mounted) setState(() => _applySlip(result));
  }

  Future<void> _save(AppLocalizations l10n) async {
    final cents = Money.parseToCents(_amount.text);
    if (cents == null || cents <= 0) {
      _snack(l10n.invalidAmount);
      return;
    }
    if (_accountId == null) {
      _snack(l10n.requiredField);
      return;
    }
    if (_type == TxnType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      _snack(l10n.requiredField);
      return;
    }
    if (_type != TxnType.transfer && _categoryId == null) {
      _snack(l10n.selectCategory);
      return;
    }

    var slipId = _slipId;
    if (_pendingSlip != null && slipId == null) {
      slipId = await ref.read(slipRepositoryProvider).save(_pendingSlip!);
    }

    await ref.read(transactionRepositoryProvider).save(
          id: widget.id,
          type: _type,
          amountCents: cents,
          accountId: _accountId!,
          toAccountId: _type == TxnType.transfer ? _toAccountId : null,
          categoryId: _type == TxnType.transfer ? null : _categoryId,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          occurredAt: _occurredAt,
          slipId: slipId,
        );
    if (mounted) context.pop();
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l10n.confirmDelete),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(transactionRepositoryProvider).delete(widget.id!);
      if (mounted) context.pop();
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.value,
    required this.onChanged,
    required this.l10n,
  });

  final TxnType value;
  final ValueChanged<TxnType> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final items = {
      TxnType.expense: (l10n.expense, AppColors.expense),
      TxnType.income: (l10n.income, AppColors.income),
      TxnType.transfer: (l10n.transfer, AppColors.transfer),
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: PixelTokens.borderRadius,
        border: PixelTokens.inkBorder(),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final entry in items.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == entry.key
                        ? entry.value.$2
                        : Colors.transparent,
                    borderRadius: PixelTokens.borderRadius,
                  ),
                  child: Text(
                    entry.value.$1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: value == entry.key
                          ? AppColors.white
                          : AppColors.gray600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<CategoryRow> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        for (final c in categories)
          GestureDetector(
            onTap: () => onSelect(c.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selectedId == c.id
                        ? AppColors.forHex(c.colorHex)
                        : AppColors.white,
                    borderRadius: PixelTokens.borderRadius,
                    border: PixelTokens.inkBorder(
                      color: selectedId == c.id
                          ? AppColors.ink
                          : AppColors.gray300,
                    ),
                  ),
                  child: Icon(
                    CategoryIcons.forKey(c.iconKey),
                    color: selectedId == c.id
                        ? AppColors.white
                        : AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
