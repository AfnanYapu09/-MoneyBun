import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/category_pixel.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_control.dart';
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

  /// false → icon grid, true → colour grid (icons shown first).
  bool _showColors = false;

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
                  CategoryChip(
                    iconKey: _iconKey,
                    colorHex: _colorHex,
                    size: 46,
                    glyphSize: 24,
                    circle: true,
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
            // Toggle between the icon grid and the colour grid (icons first).
            SegmentedControl<bool>(
              value: _showColors,
              onChanged: (v) => setState(() => _showColors = v),
              segments: const [
                Segment(value: false, label: 'ไอคอน'),
                Segment(value: true, label: 'สี'),
              ],
            ),
            const SizedBox(height: 14),
            if (!_showColors)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final k in _iconKeys)
                    InkWell(
                      onTap: () => setState(() => _iconKey = k),
                      customBorder: const CircleBorder(),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _iconKey == k
                              ? AppColors.terraWash
                              : AppColors.paper,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _iconKey == k
                                  ? AppColors.terra
                                  : AppColors.line,
                              width: _iconKey == k ? 1.5 : 1),
                        ),
                        child: PixelIcon(
                          grid: CategoryPixel.forKey(k),
                          color: AppColors.terra700,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 6,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: [
                  for (final c in _colors)
                    InkWell(
                      onTap: () => setState(() => _colorHex = c),
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
          ],
        ),
      ),
    );
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
