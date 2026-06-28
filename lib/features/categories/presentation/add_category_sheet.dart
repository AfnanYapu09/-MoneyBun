import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../domain/enums/enums.dart';

/// Bottom sheet to create a new category (icon + color + name).
class AddCategorySheet extends ConsumerStatefulWidget {
  const AddCategorySheet({super.key, this.type = CategoryType.expense});
  final CategoryType type;

  @override
  ConsumerState<AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<AddCategorySheet> {
  static const _iconKeys = [
    'food', 'coffee', 'groceries', 'shopping', 'clothing', 'entertainment',
    'games', 'music', 'movie', 'book', 'ticket', 'transport', //
    'car', 'fuel', 'bike', 'travel', 'home', 'rent', //
    'electricity', 'water', 'gas', 'phone_bill', 'phone', 'electronics', //
    'health', 'pharmacy', 'clinic', 'health_fitness', 'beauty', 'cosmetics', //
    'family', 'baby', 'dog', 'cat', 'education', 'work', //
    'gift', 'donate', 'insurance', 'debt', 'subscription', 'tax', //
    'money', 'savings', 'invest', 'sale', 'package', 'other',
  ];
  static const _colors = [
    'FFC4694A', 'FFE8732C', 'FFD9476B', 'FFD86592', 'FF3D7DCA', 'FF566AC2', //
    'FF4FA36B', 'FF6E8B6F', 'FF8A6DBF', 'FFB5739E', 'FFB5531A', 'FFA9744F', //
    'FF3FA9A0', 'FF4E8C8A', 'FF2FA8C4', 'FFD9A441', 'FFC0533F', 'FF7A736B',
  ];

  final _name = TextEditingController();
  String _iconKey = 'food';
  String _colorHex = 'FFC4694A';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'หมวดใหม่',
      fullHeight: true,
      footer: PrimaryButton(label: 'บันทึก', onPressed: _save),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live preview: chosen icon + name input.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.forHex(_colorHex),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CategoryIcons.forKey(_iconKey),
                        size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      style: AppTypography.body(size: 16),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        filled: false,
                        hintText: 'ชื่อหมวด เช่น คาเฟ่',
                        hintStyle:
                            AppTypography.body(size: 16, color: AppColors.ink3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Icon picker button.
            _PickRow(
              label: 'ไอคอน',
              onTap: _pickIcon,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.forHex(_colorHex),
                  shape: BoxShape.circle,
                ),
                child: Icon(CategoryIcons.forKey(_iconKey),
                    size: 19, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            // Colour picker button.
            _PickRow(
              label: 'สี',
              onTap: _pickColor,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.forHex(_colorHex),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIcon() async {
    final key = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SheetScaffold(
        title: 'เลือกไอคอน',
        child: GridView.count(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          crossAxisCount: 5,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: [
            for (final k in _iconKeys)
              InkWell(
                onTap: () => Navigator.of(context).pop(k),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        _iconKey == k ? AppColors.terraWash : AppColors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _iconKey == k ? AppColors.terra : AppColors.line,
                        width: _iconKey == k ? 1.5 : 1),
                  ),
                  child: Icon(CategoryIcons.forKey(k),
                      size: 22, color: AppColors.terra700),
                ),
              ),
          ],
        ),
      ),
    );
    if (key != null) setState(() => _iconKey = key);
  }

  Future<void> _pickColor() async {
    final hex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SheetScaffold(
        title: 'เลือกสี',
        child: GridView.count(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          crossAxisCount: 5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            for (final c in _colors)
              InkWell(
                onTap: () => Navigator.of(context).pop(c),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.forHex(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _colorHex == c
                            ? AppColors.ink
                            : Colors.transparent,
                        width: 3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (hex != null) setState(() => _colorHex = hex);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรอกชื่อหมวดหมู่')));
      return;
    }
    await ref.read(categoryRepositoryProvider).save(
          name: name,
          type: widget.type,
          iconKey: _iconKey,
          colorHex: _colorHex,
        );
    if (mounted) Navigator.of(context).pop(true);
  }
}

/// A tappable row: leading preview chip + label + chevron. Opens a picker.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.leading,
    required this.onTap,
  });
  final String label;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style:
                      AppTypography.heading(size: 15, weight: FontWeight.w500)),
            ),
            const Icon(AppIcons.chevronRight, size: 19, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}
