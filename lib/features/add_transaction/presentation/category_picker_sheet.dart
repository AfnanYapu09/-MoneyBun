import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

/// Result of the category/tag picker.
class CategoryPick {
  const CategoryPick(this.categoryId, this.tagIds);
  final String categoryId;
  final List<String> tagIds;
}

/// Bottom sheet: tag chips + a 4-column category grid. Tapping a category
/// returns the chosen category plus the currently selected tags.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({super.key, this.initialTagIds = const []});

  final List<String> initialTagIds;

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  late final Set<String> _tags = {...widget.initialTagIds};

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // Spending categories only — 'sys_other' is the stats fallback bucket and
    // isn't user-pickable here.
    final expense = categories
        .where((c) => c.type == CategoryType.expense && c.id != 'sys_other')
        .toList();
    final tags = ref.watch(tagsProvider).value ?? const [];

    return SheetScaffold(
      title: 'เลือกหมวดหมู่ / แท็ก',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.terraWash,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(AppIcons.hash,
                      size: 17, color: AppColors.terra700),
                ),
                for (final t in tags)
                  _TagChip(
                    label: t.name,
                    selected: _tags.contains(t.id),
                    onTap: () => setState(() => _tags.contains(t.id)
                        ? _tags.remove(t.id)
                        : _tags.add(t.id)),
                  ),
                _AddTagChip(onAdd: _addTag),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 18,
              crossAxisSpacing: 4,
              childAspectRatio: 0.78,
              children: [
                for (final c in expense)
                  _CategoryButton(
                    category: c,
                    onTap: () => Navigator.of(context)
                        .pop(CategoryPick(c.id, _tags.toList())),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('แท็กใหม่'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ชื่อแท็ก เช่น จำเป็น'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(c, controller.text.trim()),
              child: const Text('เพิ่ม')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final id = await ref.read(tagRepositoryProvider).save(name: name);
      if (mounted) setState(() => _tags.add(id));
    }
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.terra : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: selected ? AppColors.terra : AppColors.line, width: 1.5),
        ),
        child: Text('#$label',
            style: AppTypography.heading(
                size: 14,
                weight: FontWeight.w500,
                color: selected ? AppColors.reverse : AppColors.ink)),
      ),
    );
  }
}

class _AddTagChip extends StatelessWidget {
  const _AddTagChip({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onAdd,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.plus, size: 16, color: AppColors.terra),
            const SizedBox(width: 6),
            Text('เพิ่มแท็ก',
                style:
                    AppTypography.heading(size: 14, weight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({required this.category, required this.onTap});
  final CategoryRow category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(CategoryIcons.forKey(category.iconKey),
                size: 22, color: AppColors.terra700),
          ),
          const SizedBox(height: 7),
          Flexible(
            child: Text(category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 12, color: AppColors.ink2)),
          ),
        ],
      ),
    );
  }
}
