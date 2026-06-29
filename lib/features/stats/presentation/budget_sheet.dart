import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/calculator_keypad.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../add_transaction/presentation/category_picker_sheet.dart';

/// Bottom sheet to set a per-category budget — creates a new one, or edits the
/// existing [budget] when it is passed in.
class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, this.budget});

  /// When non-null, the sheet edits this budget instead of creating a new one.
  final BudgetRow? budget;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  String? _categoryId;
  final _amount = TextEditingController();
  BudgetPeriod _period = BudgetPeriod.monthly;
  bool _alert80 = true;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    if (b != null) {
      _categoryId = b.categoryId;
      _amount.text = Money.toEditString(b.amountCents);
      _period = b.period;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _openCalculator() async {
    final result = await showAmountCalculator(context, initial: _amount.text);
    if (mounted && result != null) setState(() => _amount.text = result);
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final cat = _categoryId == null ? null : categories[_categoryId];

    return SheetScaffold(
      title: widget.budget == null ? 'ตั้งงบประมาณ' : 'แก้ไขงบประมาณ',
      sizeToContent: true,
      maxHeightFactor: 0.9,
      footer: PrimaryButton(label: 'บันทึกงบ', onPressed: _save),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category selector
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickCategory,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    if (cat == null)
                      const IconChip(
                          icon: AppIcons.layoutGrid,
                          size: 38,
                          radius: 12,
                          iconSize: 19)
                    else
                      CategoryGlyph(
                          iconKey: cat.iconKey,
                          color: AppColors.forHex(cat.colorHex),
                          size: 38,
                          radius: 12,
                          iconSize: 19),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('หมวดหมู่',
                              style: AppTypography.body(
                                  size: 12.5, color: AppColors.ink3)),
                          Text(cat?.name ?? 'เลือกหมวดหมู่',
                              style: AppTypography.heading(
                                  size: 15, weight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(AppIcons.chevronRight,
                        size: 19, color: AppColors.ink3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Amount
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('จำนวนงบ',
                      style: AppTypography.body(
                          size: 12.5, color: AppColors.ink3)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amount,
                          // Tap to open the in-app calculator (no system keyboard).
                          readOnly: true,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          onTap: _openCalculator,
                          style: AppTypography.heading(
                              size: 38, weight: FontWeight.w600),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            filled: false,
                            hintText: '0',
                            hintStyle: AppTypography.heading(
                                size: 38,
                                weight: FontWeight.w600,
                                color: AppColors.ink3),
                          ),
                        ),
                      ),
                      Text('฿',
                          style: AppTypography.heading(
                              size: 24,
                              weight: FontWeight.w500,
                              color: AppColors.ink3)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Quick amounts
            Row(
              children: [
                for (final a in const [3000, 5000, 9000, 15000]) ...[
                  Expanded(
                    child: InkWell(
                      onTap: () => _amount.text = a.toString(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text('฿${_fmt(a)}',
                            style: AppTypography.heading(
                                size: 13,
                                weight: FontWeight.w500,
                                color: AppColors.ink2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text('รอบงบประมาณ',
                style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
            const SizedBox(height: 8),
            SegmentedControl<BudgetPeriod>(
              value: _period,
              onChanged: (p) => setState(() => _period = p),
              segments: const [
                Segment(value: BudgetPeriod.weekly, label: 'รายสัปดาห์'),
                Segment(value: BudgetPeriod.monthly, label: 'รายเดือน'),
                Segment(value: BudgetPeriod.yearly, label: 'รายปี'),
              ],
            ),
            const SizedBox(height: 14),
            // Alert-at-80% toggle.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.bellRing,
                      size: 19, color: AppColors.terra700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('เตือนเมื่อใช้ถึง 80%',
                        style: AppTypography.body(size: 14.5)),
                  ),
                  AppToggle(
                    value: _alert80,
                    onChanged: (v) => setState(() => _alert80 = v),
                  ),
                ],
              ),
            ),
            if (widget.budget != null) ...[
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _delete,
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
                      Text('ลบงบประมาณนี้',
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
      ),
    );
  }

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  Future<void> _pickCategory() async {
    final pick = await showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CategoryPickerSheet(),
    );
    if (pick != null) setState(() => _categoryId = pick.categoryId);
  }

  Future<void> _save() async {
    final cents = Money.parseToCents(_amount.text) ?? 0;
    if (_categoryId == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เลือกหมวดหมู่และจำนวนงบ')));
      return;
    }
    final now = DateTime.now();
    final b = widget.budget;
    final start = b?.startDate ?? AppDate.toMillis(AppDate.startOfMonth(now));
    await ref.read(databaseProvider).upsertBudget(BudgetsCompanion.insert(
          id: b?.id ?? const Uuid().v4(),
          categoryId: Value(_categoryId),
          period: _period,
          amountCents: cents,
          startDate: start,
          createdAt: b?.createdAt ?? now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final id = widget.budget?.id;
    if (id == null) return;
    await ref
        .read(databaseProvider)
        .softDeleteBudget(id, DateTime.now().millisecondsSinceEpoch);
    if (mounted) Navigator.of(context).pop(true);
  }
}
