import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
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
    'food',
    'transport',
    'shopping',
    'home',
    'entertainment',
    'health',
    'education',
    'work',
    'travel',
    'family',
    'gift',
    'package',
  ];
  static const _colors = [
    'FFC4694A',
    'FFD9476B',
    'FF3D7DCA',
    'FF4FA36B',
    'FF8A6DBF',
    'FFB5531A',
    'FF3FA9A0',
    'FF6E635A',
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
            Text('ไอคอน',
                style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final k in _iconKeys)
                  InkWell(
                    onTap: () => setState(() => _iconKey = k),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 48,
                      height: 48,
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
                      child: Icon(CategoryIcons.forKey(k),
                          size: 20, color: AppColors.terra700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('สี',
                style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in _colors) ...[
                  InkWell(
                    onTap: () => setState(() => _colorHex = c),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.forHex(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _colorHex == c
                                ? AppColors.ink
                                : Colors.transparent,
                            width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
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
