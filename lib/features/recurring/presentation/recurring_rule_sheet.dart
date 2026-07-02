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

/// Bottom sheet to create a recurring rule that auto-creates a transaction on a
/// daily / weekly / monthly schedule (materialised on app launch).
class RecurringRuleSheet extends ConsumerStatefulWidget {
  const RecurringRuleSheet({super.key, this.type = TxnType.expense});

  /// Income vs. expense is inherited from where the sheet was opened (e.g. the
  /// current tab of the Add-transaction sheet) — this form has no picker of its
  /// own, since choosing it here would just duplicate that selection.
  final TxnType type;

  @override
  ConsumerState<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

class _RecurringRuleSheetState extends ConsumerState<RecurringRuleSheet> {
  late final TxnType _type = widget.type;
  final _amount = TextEditingController();
  String? _categoryId;
  RecurFreq _freq = RecurFreq.monthly;
  DateTime _startAt = DateTime.now();
  String _calcHistory = '';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

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
      footer: PrimaryButton(label: l10n.recurSave, onPressed: _save),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                Segment(value: RecurFreq.monthly, label: l10n.recurFreqMonthly),
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
    final l10n = AppLocalizations.of(context);
    final cents = Money.parseToCents(_amount.text) ?? 0;
    if (cents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addtxnEnterAmount)));
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await ref.read(databaseProvider).upsertRecurringRule(
          RecurringRulesCompanion.insert(
            id: const Uuid().v4(),
            type: _type,
            amountCents: cents,
            freq: _freq,
            nextRunAt: AppDate.toMillis(_startAt),
            createdAt: now,
            updatedAt: now,
            categoryId: Value(_categoryId),
          ),
        );
    if (mounted) Navigator.of(context).pop(true);
  }
}
