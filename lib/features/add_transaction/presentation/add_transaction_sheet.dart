import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../transactions/presentation/widgets/account_flow.dart';
import 'category_picker_sheet.dart';

/// Full-height Add/Edit transaction sheet with expense/income/transfer tabs.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  TxnType _type = TxnType.expense;
  final _amount = TextEditingController();
  String? _categoryId;
  List<String> _tagIds = [];
  String? _note;
  String? _fromAccountId;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  SlipRow? _slip;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.editId != null) {
      final repo = ref.read(transactionRepositoryProvider);
      final row = await repo.get(widget.editId!);
      if (row != null) {
        _type = row.type;
        _amount.text =
            row.amountCents == 0 ? '' : Money.toEditString(row.amountCents);
        _categoryId = row.categoryId;
        _note = row.note;
        _fromAccountId = row.accountId.isEmpty ? null : row.accountId;
        _toAccountId = row.toAccountId;
        _occurredAt = AppDate.fromMillis(row.occurredAt);
        _tagIds = await repo.tagIds(widget.editId!);
        if (row.slipId != null) {
          final slips = await ref.read(slipsByIdProvider.future);
          _slip = slips[row.slipId];
        }
        // A slip whose sender == receiver moves money between the user's own
        // accounts — it's a transfer (no category), persisted so stats stay right.
        if (isSelfTransfer(_slip)) {
          _type = TxnType.transfer;
          if (row.type != TxnType.transfer) {
            await repo.reclassifyAsTransfer(widget.editId!);
          }
        }
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Color get _accent =>
      _type == TxnType.income ? AppColors.green : AppColors.terra;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];

    return FullSheetScaffold(
      header: SegmentedControl<TxnType>(
        iconOverLabel: true,
        value: _type,
        onChanged: (t) => setState(() => _type = t),
        segments: const [
          Segment(
              value: TxnType.expense,
              label: 'รายจ่าย',
              icon: AppIcons.arrowUpRight,
              color: AppColors.terra),
          Segment(
              value: TxnType.income,
              label: 'รายรับ',
              icon: AppIcons.arrowDownLeft,
              color: AppColors.green),
          Segment(
              value: TxnType.transfer,
              label: 'ย้ายเงิน',
              icon: AppIcons.arrowLeftRight,
              color: AppColors.terra),
        ],
      ),
      footer: PrimaryButton(
        label: 'บันทึก',
        color: _accent,
        onPressed: _loaded ? _save : null,
        loading: !_loaded,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          // Date chip
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.calendar,
                      size: 18, color: AppColors.terra700),
                  const SizedBox(width: 8),
                  Text(AppDate.formatDayHeader(_occurredAt, locale: locale),
                      style: AppTypography.heading(
                          size: 15,
                          weight: FontWeight.w500,
                          color: AppColors.terra700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Amount card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(_directionIcon, size: 30, color: _accent),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    style: AppTypography.heading(
                        size: 40,
                        weight: FontWeight.w600,
                        color: AppColors.ink),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      hintText: '0',
                      hintStyle: AppTypography.heading(
                          size: 40,
                          weight: FontWeight.w600,
                          color: AppColors.ink3),
                    ),
                  ),
                ),
                Text('฿',
                    style: AppTypography.heading(
                        size: 26,
                        weight: FontWeight.w500,
                        color: AppColors.ink3)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Category (non-transfer only)
          if (_type != TxnType.transfer) ...[
            _Row(
              icon: AppIcons.layoutGrid,
              label: 'เลือกหมวดหมู่ / แท็ก',
              value: _categoryLabel(categories),
              onTap: _pickCategory,
            ),
            const SizedBox(height: 14),
          ],
          // Account: a slip-backed entry shows the bank→bank / name→name flow
          // read from the slip (read-only); manual entries keep the picker.
          if (_slip != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('บัญชี',
                  style: AppTypography.heading(
                      size: 13,
                      weight: FontWeight.w500,
                      color: AppColors.ink3)),
            ),
            accountFlowFor(
              type: _type,
              accounts: accounts,
              accountId: _fromAccountId,
              toAccountId: _toAccountId,
              slip: _slip,
            ),
            const SizedBox(height: 14),
            SlipChip(onTap: () => showSlipViewer(context, _slip!)),
            const SizedBox(height: 14),
          ] else if (_type == TxnType.transfer) ...[
            _Row(
              icon: AppIcons.wallet,
              label: 'จากบัญชี',
              value: _accountName(accounts, _fromAccountId),
              onTap: () => _pickAccount(accounts, true),
            ),
            const SizedBox(height: 14),
            _Row(
              icon: AppIcons.arrowDown,
              label: 'ไปยังบัญชี',
              value: _accountName(accounts, _toAccountId),
              onTap: () => _pickAccount(accounts, false),
            ),
            const SizedBox(height: 14),
          ] else ...[
            _Row(
              icon: AppIcons.wallet,
              label: 'บัญชี',
              value: _accountName(accounts, _fromAccountId),
              onTap: () => _pickAccount(accounts, true),
            ),
            const SizedBox(height: 14),
          ],
          // Note
          _Row(
            icon: AppIcons.pencilLine,
            label: 'เพิ่มโน้ต',
            value: _note,
            onTap: _editNote,
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Text('เพิ่มเติม',
                style: AppTypography.heading(
                    size: 13, weight: FontWeight.w500, color: AppColors.ink3)),
          ),
          const SizedBox(height: 10),
          _Row(
            icon: AppIcons.repeat,
            label: 'จดซ้ำล่วงหน้า',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('จดซ้ำล่วงหน้า — เร็วๆ นี้'))),
          ),
          if (widget.editId != null) ...[
            const SizedBox(height: 22),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _confirmDelete,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.dangerWash,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(AppIcons.trash2,
                        size: 19, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Text('ลบรายการนี้',
                        style: AppTypography.heading(
                            size: 16,
                            weight: FontWeight.w500,
                            color: AppColors.danger)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData get _directionIcon => switch (_type) {
        TxnType.income => AppIcons.arrowDownLeft,
        TxnType.transfer => AppIcons.arrowLeftRight,
        TxnType.expense => AppIcons.arrowUpRight,
      };

  String? _categoryLabel(Map<String, CategoryRow> categories) {
    if (_categoryId == null) return null;
    final c = categories[_categoryId];
    final tagSuffix = _tagIds.isEmpty ? '' : ' · ${_tagIds.length} แท็ก';
    return c == null ? null : '${c.name}$tagSuffix';
  }

  String? _accountName(List<AccountRow> accounts, String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  Future<void> _pickCategory() async {
    final pick = await showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(initialTagIds: _tagIds),
    );
    if (pick != null) {
      setState(() {
        _categoryId = pick.categoryId;
        _tagIds = pick.tagIds;
      });
    }
  }

  Future<void> _pickAccount(List<AccountRow> accounts, bool from) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SheetScaffold(
        title: from ? 'เลือกบัญชี' : 'ไปยังบัญชี',
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: [
            for (final a in accounts)
              ListTile(
                leading: IconChip(
                  icon: CategoryIcons.forKey(a.iconKey),
                  size: 38,
                  iconSize: 18,
                  background: a.colorHex == null
                      ? AppColors.terraWash
                      : AppColors.forHex(a.colorHex!),
                  foreground:
                      a.colorHex == null ? AppColors.terra700 : Colors.white,
                  circle: true,
                ),
                title: Text(a.name, style: AppTypography.body(size: 15)),
                onTap: () => Navigator.pop(context, a.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) {
      setState(() => from ? _fromAccountId = id : _toAccountId = id);
    }
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note);
    final note = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('โน้ต'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'รายละเอียด (ไม่บังคับ)'),
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
    if (note != null) setState(() => _note = note.isEmpty ? null : note);
  }

  Future<void> _pickDate() async {
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
    setState(() => _occurredAt = DateTime(date.year, date.month, date.day,
        time?.hour ?? _occurredAt.hour, time?.minute ?? _occurredAt.minute));
  }

  Future<void> _save() async {
    final cents = Money.parseToCents(_amount.text) ?? 0;
    if (cents <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')));
      return;
    }
    final accounts = ref.read(accountsProvider).value ?? const <AccountRow>[];
    final defaultAccount = accounts.isEmpty ? null : accounts.first.id;
    await ref.read(transactionRepositoryProvider).save(
          id: widget.editId,
          type: _type,
          amountCents: cents,
          accountId: _fromAccountId ?? defaultAccount ?? '',
          toAccountId: _type == TxnType.transfer ? _toAccountId : null,
          categoryId: _type == TxnType.transfer ? null : _categoryId,
          note: _note,
          occurredAt: _occurredAt,
          tagIds: _type == TxnType.transfer ? const [] : _tagIds,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: const Text('ต้องการลบรายการนี้ใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(transactionRepositoryProvider).delete(widget.editId!);
      if (mounted) Navigator.of(context).pop(true);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            IconChip(icon: icon, size: 36, radius: 11, iconSize: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(value ?? label,
                  style: AppTypography.body(
                      size: 15,
                      color: value == null ? AppColors.ink2 : AppColors.ink)),
            ),
            const Icon(AppIcons.chevronRight, size: 19, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}
