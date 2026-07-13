import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/calculator.dart';
import '../../../core/utils/category_l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/calculator_keypad.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../add_transaction/presentation/category_picker_sheet.dart';

/// Bottom sheet to create OR edit a recurring rule that auto-creates a
/// transaction on a daily / weekly / monthly schedule (materialised on app
/// launch). Pass [rule] to edit an existing one.
class RecurringRuleSheet extends ConsumerStatefulWidget {
  const RecurringRuleSheet({super.key, this.type = TxnType.expense, this.rule});

  /// Income vs. expense is inherited from where the sheet was opened (e.g. the
  /// current tab of the Add-transaction sheet) — this form has no picker of its
  /// own, since choosing it here would just duplicate that selection.
  final TxnType type;

  /// When set, the sheet edits this rule instead of creating a new one.
  final RecurringRuleRow? rule;

  @override
  ConsumerState<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

class _RecurringRuleSheetState extends ConsumerState<RecurringRuleSheet> {
  late final TxnType _type = widget.rule?.type ?? widget.type;
  late final _amount = TextEditingController(
    text:
        widget.rule == null ? '' : Money.toEditString(widget.rule!.amountCents),
  );
  late String? _categoryId = widget.rule?.categoryId;
  late RecurFreq _freq = widget.rule?.freq ?? RecurFreq.monthly;
  late DateTime _startAt = widget.rule == null
      ? DateTime.now()
      : AppDate.fromMillis(widget.rule!.nextRunAt);
  String _calcHistory = '';
  final _scroll = ScrollController();
  bool _calcOpen = false;

  /// Single-flight guard: a double-tap on save would create two identical
  /// rules — and every future occurrence would then be created twice.
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openCalculator() async {
    final original = _amount.text;
    _showCalcRoom();
    await showAmountCalculator(
      context,
      initial: original,
      onChanged: (text, history) {
        _amount.text = text;
        setState(() => _calcHistory = history);
      },
    );
    if (!mounted) return;
    setState(() => _calcOpen = false);
    final value = Calculator.evaluate(_amount.text);
    _amount.text = value == null ? original : Calculator.formatResult(value);
  }

  /// Dock the amount card flush above the in-app calculator: while the keypad is
  /// open the fields below the amount are hidden and the sheet's bottom room is
  /// set to the keypad height, so the amount box sits right on top of the keypad
  /// (scrolled fully into view on short screens). Reversed when the keypad closes.
  void _showCalcRoom() {
    setState(() => _calcOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };
    final cat = _categoryId == null ? null : categories[_categoryId];

    return SheetScaffold(
      title: l10n.recurTitle,
      sizeToContent: true,
      maxHeightFactor: 0.9,
      footer: _calcOpen
          ? null
          : PrimaryButton(
              label: l10n.recurSave,
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
      child: SingleChildScrollView(
        controller: _scroll,
        // While the keypad is open the bottom room equals the keypad height, so
        // the amount card (the fields below it are hidden) docks flush on top of
        // the calculator instead of floating at the top of the screen.
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          _calcOpen ? 382 + MediaQuery.of(context).padding.bottom : 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.palette.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.recurAmount,
                    style: AppTypography.body(
                      size: 12.5,
                      color: context.palette.ink3,
                    ),
                  ),
                  CalcHistoryLine(_calcHistory),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amount,
                          readOnly: true,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          onTap: _openCalculator,
                          style: AppTypography.heading(
                            size: 38,
                            weight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            filled: false,
                            hintText: '0',
                            hintStyle: AppTypography.heading(
                              size: 38,
                              weight: FontWeight.w600,
                              color: context.palette.ink3,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '฿',
                        style: AppTypography.heading(
                          size: 24,
                          weight: FontWeight.w500,
                          color: context.palette.ink3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // The keypad covers everything below the amount, so hide it while
            // the calculator is open and dock the amount box on top of it.
            if (!_calcOpen) ...[
              const SizedBox(height: 14),
              // Category
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickCategory,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.palette.line),
                  ),
                  child: Row(
                    children: [
                      if (cat == null)
                        const IconChip(
                          icon: AppIcons.layoutGrid,
                          size: 38,
                          radius: 12,
                          iconSize: 19,
                        )
                      else
                        CategoryGlyph(
                          iconKey: cat.iconKey,
                          color: AppColors.forHex(cat.colorHex),
                          size: 38,
                          radius: 12,
                          iconSize: 19,
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          cat?.displayName(locale) ?? l10n.selectCategory,
                          style: AppTypography.heading(
                            size: 15,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        AppIcons.chevronRight,
                        size: 19,
                        color: context.palette.ink3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.recurFrequency,
                style: AppTypography.body(
                  size: 12.5,
                  color: context.palette.ink3,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedControl<RecurFreq>(
                value: _freq,
                onChanged: (f) => setState(() => _freq = f),
                segments: [
                  Segment(value: RecurFreq.daily, label: l10n.recurFreqDaily),
                  Segment(value: RecurFreq.weekly, label: l10n.recurFreqWeekly),
                  Segment(
                    value: RecurFreq.monthly,
                    label: l10n.recurFreqMonthly,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Start date
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.palette.line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.calendar,
                        size: 19,
                        color: context.palette.terraFg,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.recurStartDate,
                          style: AppTypography.body(size: 14.5),
                        ),
                      ),
                      Text(
                        AppDate.formatDayHeader(_startAt, locale: locale),
                        style: AppTypography.heading(
                          size: 14,
                          weight: FontWeight.w500,
                          color: context.palette.terraFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategory() async {
    final pick = await showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(
        categoryType: _type == TxnType.income
            ? CategoryType.income
            : CategoryType.expense,
      ),
    );
    if (pick != null) setState(() => _categoryId = pick.categoryId);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(
      () => _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        _startAt.hour,
        _startAt.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final cents = Money.parseToCents(_amount.text) ?? 0;
    if (cents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addtxnEnterAmount)));
      return;
    }
    setState(() => _busy = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final rule = widget.rule;
      await ref.read(databaseProvider).upsertRecurringRule(
            RecurringRulesCompanion.insert(
              // Editing keeps the rule's identity + creation time; a new rule
              // gets fresh ones.
              id: rule?.id ?? const Uuid().v4(),
              type: _type,
              amountCents: cents,
              freq: _freq,
              nextRunAt: AppDate.toMillis(_startAt),
              anchorDay: Value(_startAt.day),
              createdAt: rule?.createdAt ?? now,
              updatedAt: now,
              categoryId: Value(_categoryId),
              // upsertRecurringRule only writes columns present on the
              // companion, so an edit of an already-synced rule must flag
              // itself for push here — otherwise the row stays `synced`, the
              // change never uploads, and another device's runDue() bump
              // reverts it via last-write-wins.
              syncStatus: Value(
                rule == null || rule.syncStatus == SyncStatus.pendingCreate
                    ? SyncStatus.pendingCreate
                    : SyncStatus.pendingUpdate,
              ),
            ),
          );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }
}
