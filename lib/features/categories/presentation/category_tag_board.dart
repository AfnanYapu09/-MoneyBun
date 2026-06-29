import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/pixel_icon.dart';
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

  /// Manage mode only: iOS-style "wiggle" edit mode for drag-reorder + delete.
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.type == widget.categoryType && c.id != 'sys_other')
        .toList();
    final tags = ref.watch(tagsProvider).value ?? const <TagRow>[];
    final editing = widget.manage && _editing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag chips (hidden while reordering categories, to keep focus).
        if (!editing)
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
          if (editing)
            _CategoryEditList(
              categories: categories,
              onReorder: (ids) =>
                  ref.read(categoryRepositoryProvider).reorder(ids),
              onDelete: _confirmDeleteCategory,
              onDone: () => setState(() => _editing = false),
            )
          else ...[
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
                    onLongPress: widget.manage
                        ? () => setState(() => _editing = true)
                        : null,
                  ),
                if (widget.manage) _AddCategoryButton(onTap: _addCategory),
              ],
            ),
            if (widget.manage) ...[
              const SizedBox(height: 12),
              Center(
                child: Text('กดค้างที่หมวดเพื่อจัดเรียงหรือลบ',
                    style:
                        AppTypography.body(size: 12.5, color: AppColors.ink3)),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Future<void> _confirmDeleteCategory(CategoryRow c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('ลบหมวด "${c.name}" ใช่ไหม?\n'
            'รายการเก่าที่ใช้หมวดนี้จะกลายเป็น "อื่นๆ"'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(categoryRepositoryProvider).delete(c.id);
    }
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
  const _CategoryButton({
    required this.category,
    required this.onTap,
    this.onLongPress,
  });
  final CategoryRow category;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryGlyph(
            iconKey: category.iconKey,
            color: AppColors.forHex(category.colorHex),
            size: 52,
            radius: 16,
            iconSize: 24,
            circle: true,
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

/// Manage-mode edit state: the category list jiggles, each row can be dragged by
/// the handle to reorder, and a red − badge deletes it. A "เสร็จ" button exits.
class _CategoryEditList extends StatefulWidget {
  const _CategoryEditList({
    required this.categories,
    required this.onReorder,
    required this.onDelete,
    required this.onDone,
  });

  final List<CategoryRow> categories;

  /// Persist the new full order (list of category ids, top to bottom).
  final void Function(List<String> idsInOrder) onReorder;
  final Future<void> Function(CategoryRow category) onDelete;
  final VoidCallback onDone;

  @override
  State<_CategoryEditList> createState() => _CategoryEditListState();
}

class _CategoryEditListState extends State<_CategoryEditList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..repeat();

  // A local working copy so reordering is instant; re-synced from the provider
  // only when the set of categories changes (an add/delete), not on a reorder.
  late List<CategoryRow> _items = [...widget.categories];

  @override
  void didUpdateWidget(_CategoryEditList old) {
    super.didUpdateWidget(old);
    final incoming = widget.categories.map((c) => c.id).toSet();
    final current = _items.map((c) => c.id).toSet();
    if (incoming.length != current.length || !incoming.containsAll(current)) {
      _items = [...widget.categories];
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
    });
    widget.onReorder(_items.map((c) => c.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('ลากเพื่อจัดเรียง · แตะ − เพื่อลบ',
                  style: AppTypography.body(size: 13, color: AppColors.ink3)),
            ),
            TextButton(
              onPressed: widget.onDone,
              child: Text('เสร็จ',
                  style: AppTypography.heading(
                      size: 15, weight: FontWeight.w600, color: AppColors.terra)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _items.length,
          onReorder: _onReorder,
          itemBuilder: (context, i) {
            final c = _items[i];
            return _EditRow(
              key: ValueKey(c.id),
              category: c,
              index: i,
              wiggle: _wiggle,
              onDelete: () => widget.onDelete(c),
            );
          },
        ),
      ],
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    super.key,
    required this.category,
    required this.index,
    required this.wiggle,
    required this.onDelete,
  });

  final CategoryRow category;
  final int index;
  final Animation<double> wiggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          // Delete (−) badge.
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onDelete,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.minus, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          CategoryGlyph(
            iconKey: category.iconKey,
            color: AppColors.forHex(category.colorHex),
            size: 40,
            radius: 13,
            circle: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 15)),
          ),
          // Drag handle ("กดข้างตรงไอคอน").
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(AppIcons.gripVertical, size: 22, color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );

    // Subtle continuous "wiggle" so the list reads as editable. Phase-shift by
    // index so rows don't rock in unison.
    return AnimatedBuilder(
      animation: wiggle,
      builder: (context, child) {
        final angle =
            math.sin(wiggle.value * 2 * math.pi + index * 0.9) * 0.018;
        return Transform.rotate(angle: angle, child: child);
      },
      child: row,
    );
  }
}
