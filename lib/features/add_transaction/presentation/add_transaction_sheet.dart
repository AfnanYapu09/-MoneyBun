import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/calculator.dart';
import '../../../core/utils/category_l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/calculator_keypad.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
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
  String _calcHistory = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
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
            // Fetch just this slip, not the whole table, so the form never
            // stalls hydrating every slip's OCR text.
            _slip = await ref.read(slipRepositoryProvider).get(row.slipId!);
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
    } catch (_) {
      // A failed load must never leave the save button spinning — open the
      // form with whatever loaded so the user can still edit and save.
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Color _accentOf(BuildContext context) => switch (_type) {
        TxnType.income => context.palette.greenFg,
        TxnType.transfer => context.palette.amberFg,
        TxnType.expense => AppColors.terra,
      };

  /// Solid accent for the save-button FILL (a white label sits on top), so it
  /// stays legible in both themes — unlike the lighter foreground [_accentOf].
  Color _fillAccentOf() => switch (_type) {
        TxnType.income => AppColors.green,
        TxnType.transfer => AppColors.amber,
        TxnType.expense => AppColors.terra,
      };

  /// Open the orange in-app calculator. Keypresses appear live in the field;
  /// on close the expression left there is resolved to a number (edit mode
  /// then persists, mirroring the old onChanged hook).
  Future<void> _openCalculator() async {
    final original = _amount.text;
    await showAmountCalculator(
      context,
      initial: original,
      onChanged: (text, history) {
        _amount.text = text;
        setState(() => _calcHistory = history);
      },
    );
    if (!mounted) return;
    final value = Calculator.evaluate(_amount.text);
    _amount.text = value == null ? original : Calculator.formatResult(value);
    // Keep _calcHistory as the keypad left it — it lingers above the amount
    // until the sheet is closed.
    _persistLive();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };

    return FullSheetScaffold(
      header: SegmentedControl<TxnType>(
        iconOverLabel: true,
        value: _type,
        onChanged: (t) {
          // Category sets differ by type, so clear the held category on switch.
          setState(() {
            _type = t;
            _categoryId = null;
          });
          _persistLive();
        },
        segments: [
          Segment(
            value: TxnType.expense,
            label: l10n.expense,
            icon: AppIcons.arrowUpRight,
            color: AppColors.terra,
          ),
          Segment(
            value: TxnType.income,
            label: l10n.income,
            icon: AppIcons.arrowDownLeft,
            color: context.palette.greenFg,
          ),
        ],
      ),
      // Edit mode saves live (every change persists); only the Add flow keeps a
      // commit button.
      footer: _footer(context),
      child: ListView(
        shrinkWrap: true,
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
                  Icon(
                    AppIcons.calendar,
                    size: 18,
                    color: context.palette.terraFg,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppDate.formatDayHeader(_occurredAt, locale: locale),
                    style: AppTypography.heading(
                      size: 15,
                      weight: FontWeight.w500,
                      color: context.palette.terraFg,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Amount card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.palette.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalcHistoryLine(_calcHistory),
                Row(
                  children: [
                    Icon(_directionIcon, size: 30, color: _accentOf(context)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        // Tapping opens the in-app calculator instead of the
                        // system keyboard (amounts can be worked out inline).
                        readOnly: true,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        onTap: _openCalculator,
                        style: AppTypography.heading(
                          size: 40,
                          weight: FontWeight.w600,
                          color: context.palette.ink,
                        ),
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
                            color: context.palette.ink3,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '฿',
                      style: AppTypography.heading(
                        size: 26,
                        weight: FontWeight.w500,
                        color: context.palette.ink3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Category (non-transfer only)
          if (_type != TxnType.transfer) ...[
            _Row(
              icon: AppIcons.layoutGrid,
              label: l10n.addtxnPickCategoryTag,
              value: _categoryLabel(categories, l10n, locale),
              onTap: _pickCategory,
            ),
            const SizedBox(height: 14),
          ],
          // Slip-backed entries keep a link to the original slip. The manual
          // account picker was removed — entries default to the first account.
          if (_slip != null) ...[
            SlipChip(onTap: () => showSlipViewer(context, _slip!)),
            const SizedBox(height: 14),
          ],
          // Note
          _Row(
            icon: AppIcons.pencilLine,
            label: l10n.addtxnAddNote,
            value: _note,
            onTap: _editNote,
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Text(
              l10n.addtxnMore,
              style: AppTypography.heading(
                size: 13,
                weight: FontWeight.w500,
                color: context.palette.ink3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Row(
            icon: AppIcons.repeat,
            label: l10n.addtxnRecurring,
            // Carry the current tab's direction into the recurring form so it
            // needn't ask again (transfers have no recurring rule → expense).
            onTap: () => showRecurringRuleSheet(
              context,
              type: _type == TxnType.income ? TxnType.income : TxnType.expense,
            ),
          ),
          if (widget.editId != null) ...[
            const SizedBox(height: 22),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _confirmDelete,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: context.palette.dangerWash,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.trash2,
                      size: 19,
                      color: context.palette.dangerFg,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.addtxnDeleteEntry,
                      style: AppTypography.heading(
                        size: 16,
                        weight: FontWeight.w500,
                        color: context.palette.dangerFg,
                      ),
                    ),
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

  String? _categoryLabel(
    Map<String, CategoryRow> categories,
    AppLocalizations l10n,
    String locale,
  ) {
    if (_categoryId == null) return null;
    final c = categories[_categoryId];
    final tagSuffix =
        _tagIds.isEmpty ? '' : l10n.addtxnTagSuffix(_tagIds.length);
    return c == null ? null : '${c.displayName(locale)}$tagSuffix';
  }

  Future<void> _pickCategory() async {
    final pick = await showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(
        initialTagIds: _tagIds,
        categoryType: _type == TxnType.income
            ? CategoryType.income
            : CategoryType.expense,
      ),
    );
    if (pick != null) {
      setState(() {
        _categoryId = pick.categoryId;
        _tagIds = pick.tagIds;
      });
      _persistLive();
    }
  }

  Future<void> _editNote() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _note);
    final note = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.addtxnNoteTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.addtxnNoteDetailHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (note != null) {
      setState(() => _note = note.isEmpty ? null : note);
      _persistLive();
    }
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
    setState(
      () => _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      ),
    );
    _persistLive();
  }

  /// Add mode keeps a commit button; edit mode saves live (no button).
  Widget? _footer(BuildContext context) {
    if (widget.editId != null) return null;
    final l10n = AppLocalizations.of(context);
    return PrimaryButton(
      label: l10n.save,
      color: _fillAccentOf(),
      onPressed: _loaded ? _save : null,
      loading: !_loaded,
    );
  }

  /// Edit mode only: persist the current form immediately on every change, so
  /// there is no Save button. Silent (no validation snackbar, no pop) — the
  /// home/stats lists update live via their streams.
  Future<void> _persistLive() async {
    if (widget.editId == null || !_loaded) return;
    final cents = Money.parseToCents(_amount.text) ?? 0;
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
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final cents = Money.parseToCents(_amount.text) ?? 0;
    if (cents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addtxnEnterAmount)));
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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l10n.addtxnConfirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.delete),
          ),
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
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.palette.line),
        ),
        child: Row(
          children: [
            IconChip(icon: icon, size: 36, radius: 11, iconSize: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value ?? label,
                style: AppTypography.body(
                  size: 15,
                  color: value == null
                      ? context.palette.ink2
                      : context.palette.ink,
                ),
              ),
            ),
            Icon(AppIcons.chevronRight, size: 19, color: context.palette.ink3),
          ],
        ),
      ),
    );
  }
}
