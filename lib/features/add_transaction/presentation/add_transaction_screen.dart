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
import '../../../core/widgets/slip_image.dart';
import '../../../data/local/database.dart';

/// View / edit one slip entry: its image, amount, date, note and category.
/// Also used to add a manual entry (no [id]) when OCR couldn't read a slip.
class EntryEditorScreen extends ConsumerStatefulWidget {
  const EntryEditorScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends ConsumerState<EntryEditorScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _categoryId;
  String? _slipId;
  SlipRow? _slip;
  DateTime _occurredAt = DateTime.now();
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
        _amount.text =
            row.amountCents == 0 ? '' : Money.toEditString(row.amountCents);
        _note.text = row.note ?? '';
        _categoryId = row.categoryId;
        _occurredAt = AppDate.fromMillis(row.occurredAt);
        _slipId = row.slipId;
        if (_slipId != null) {
          _slip = await ref.read(slipRepositoryProvider).get(_slipId!);
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final locale = ref.watch(localeProvider).languageCode;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'รายการสลิป' : 'เพิ่มรายการ'),
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
          if (_slip != null) ...[
            AspectRatio(
              aspectRatio: 3 / 2,
              child: ClipRRect(
                borderRadius: PixelTokens.borderRadius,
                child: Container(
                  decoration: BoxDecoration(
                    border: PixelTokens.inkBorder(),
                    borderRadius: PixelTokens.borderRadius,
                  ),
                  child: SlipImage(slip: _slip, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.expense),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
                labelText: 'จำนวนเงิน', prefixText: '฿ ', hintText: '0.00'),
          ),
          const SizedBox(height: 16),
          const Text('เลือกหมวดหมู่',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _CategoryGrid(
            categories: categories,
            selectedId: _categoryId,
            onSelect: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDateTime,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'วันและเวลา'),
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
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'บันทึกช่วยจำ', hintText: 'รายละเอียด (ไม่บังคับ)'),
          ),
          const SizedBox(height: 24),
          PixelButton(label: 'บันทึก', expand: true, onPressed: _save),
        ],
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
      _occurredAt = DateTime(date.year, date.month, date.day,
          time?.hour ?? _occurredAt.hour, time?.minute ?? _occurredAt.minute);
    });
  }

  Future<void> _save() async {
    final cents = Money.parseToCents(_amount.text) ?? 0;
    await ref.read(transactionRepositoryProvider).save(
          id: widget.id,
          amountCents: cents,
          categoryId: _categoryId,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          occurredAt: _occurredAt,
          slipId: _slipId,
        );
    if (mounted) context.pop();
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
      await ref.read(transactionRepositoryProvider).delete(widget.id!);
      if (mounted) context.pop();
    }
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
      childAspectRatio: 0.82,
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
                  child: Icon(CategoryIcons.forKey(c.iconKey),
                      color: selectedId == c.id
                          ? AppColors.white
                          : AppColors.gray600),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
