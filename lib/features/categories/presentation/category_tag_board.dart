import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

/// Shared category-grid + tag-chips board used by BOTH the transaction
/// category picker (select mode) and the Settings "manage" screens (manage
/// mode), so the two look and behave identically.
///
/// - Select mode (`manage: false`): tapping a category calls [onPick] with the
///   chosen category id + the currently selected tag ids; tapping a tag toggles
///   it; the add-tag chip creates a tag.
/// - Manage mode (`manage: true`): tapping a category renames it, the add tile
///   opens the new-category sheet, and tags can be renamed/deleted/added.
class CategoryTagBoard extends ConsumerStatefulWidget {
  const CategoryTagBoard({
    super.key,
    required this.categoryType,
    this.manage = false,
    this.showCategories = true,
    this.initialTagIds = const [],
    this.onPick,
  });

  final CategoryType categoryType;
  final bool manage;
  final bool showCategories;
  final List<String> initialTagIds;
  final void Function(String categoryId, List<String> tagIds)? onPick;

  @override
  ConsumerState<CategoryTagBoard> createState() => _CategoryTagBoardState();
}

class _CategoryTagBoardState extends ConsumerState<CategoryTagBoard> {
  late final Set<String> _tags = {...widget.initialTagIds};

  @override
  Widget build(BuildContext context) {
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.type == widget.categoryType && c.id != 'sys_other')
        .toList();
    final tags = ref.watch(tagsProvider).value ?? const <TagRow>[];

    return Column(
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
                selected: !widget.manage && _tags.contains(t.id),
                onTap: () => widget.manage
                    ? _editTag(t)
                    : setState(() => _tags.contains(t.id)
                        ? _tags.remove(t.id)
                        : _tags.add(t.id)),
              ),
            _AddTagChip(onAdd: _addTag),
          ],
        ),
        if (widget.showCategories) ...[
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 18,
            crossAxisSpacing: 4,
            childAspectRatio: 0.78,
            children: [
              for (final c in categories)
                _CategoryButton(
                  category: c,
                  onTap: () => widget.manage
                      ? _editCategory(c)
                      : widget.onPick?.call(c.id, _tags.toList()),
                ),
              if (widget.manage) _AddCategoryButton(onTap: _addCategory),
            ],
          ),
        ],
      ],
    );
  }

  void _addCategory() =>
      showAddCategorySheet(context, type: widget.categoryType);

  Future<void> _editCategory(CategoryRow c) async {
    final controller = TextEditingController(text: c.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ชื่อหมวดหมู่'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('บันทึก')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(categoryRepositoryProvider).rename(c.id, name);
    }
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
      if (mounted && !widget.manage) setState(() => _tags.add(id));
    }
  }

  Future<void> _editTag(TagRow t) async {
    final controller = TextEditingController(text: t.name);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขแท็ก'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, '__delete__'),
            child: const Text('ลบ', style: TextStyle(color: AppColors.danger)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('บันทึก')),
        ],
      ),
    );
    if (action == null) return;
    final repo = ref.read(tagRepositoryProvider);
    if (action == '__delete__') {
      await repo.delete(t.id);
    } else if (action.isNotEmpty) {
      await repo.save(
          id: t.id, name: action, colorHex: t.colorHex, sortOrder: t.sortOrder);
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
              color: AppColors.forHex(category.colorHex),
              shape: BoxShape.circle,
            ),
            child: Icon(CategoryIcons.forKey(category.iconKey),
                size: 24, color: Colors.white),
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

class _AddCategoryButton extends StatelessWidget {
  const _AddCategoryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashedBorder(
            radius: 26,
            strokeWidth: 1.5,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: Icon(AppIcons.plus, size: 22, color: AppColors.terra),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Flexible(
            child: Text('เพิ่ม',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 12, color: AppColors.terra)),
          ),
        ],
      ),
    );
  }
}
