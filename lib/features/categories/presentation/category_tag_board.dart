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
import '../../../l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
                  color: context.palette.terraWash,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(AppIcons.hash,
                    size: 17, color: context.palette.terraFg),
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
          if (!widget.manage)
            // Select mode (picker): a plain grid; tapping picks the category.
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
                    onTap: () => widget.onPick?.call(c.id, _tags.toList()),
                  ),
              ],
            )
          else ...[
            // Manage mode: long-press an icon to enter the iOS-style wiggle
            // edit mode, then drag it anywhere in the grid to reorder.
            if (editing)
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.catReorderHint,
                        style: AppTypography.body(
                            size: 13, color: context.palette.ink3)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _editing = false),
                    child: Text(l10n.catDone,
                        style: AppTypography.heading(
                            size: 15,
                            weight: FontWeight.w600,
                            color: AppColors.terra)),
                  ),
                ],
              ),
            _ManagedCategoryGrid(
              categories: categories,
              editing: editing,
              onEnterEdit: () => setState(() => _editing = true),
              onReorder: (ids) =>
                  ref.read(categoryRepositoryProvider).reorder(ids),
              onDelete: _confirmDeleteCategory,
              onRename: _editCategory,
              onAdd: _addCategory,
            ),
            if (!editing) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(l10n.catLongPressHint,
                    style: AppTypography.body(
                        size: 12.5, color: context.palette.ink3)),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Future<void> _confirmDeleteCategory(CategoryRow c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.catConfirmDelete(c.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: TextStyle(color: context.palette.dangerFg)),
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
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: c.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catRenameTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.save)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(categoryRepositoryProvider).rename(c.id, name);
    }
  }

  Future<void> _addTag() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.tagNewTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.tagNameHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(c, controller.text.trim()),
              child: Text(l10n.catAdd)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final id = await ref.read(tagRepositoryProvider).save(name: name);
      if (mounted && !widget.manage) setState(() => _tags.add(id));
    }
  }

  Future<void> _editTag(TagRow t) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: t.name);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tagEditTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, '__delete__'),
            child: Text(l10n.delete,
                style: TextStyle(color: context.palette.dangerFg)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.save)),
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
              color: selected ? AppColors.terra : context.palette.line,
              width: 1.5),
        ),
        child: Text('#$label',
            style: AppTypography.heading(
                size: 14,
                weight: FontWeight.w500,
                color: selected ? AppColors.reverse : context.palette.ink)),
      ),
    );
  }
}

class _AddTagChip extends StatelessWidget {
  const _AddTagChip({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onAdd,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: context.palette.line, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.plus, size: 16, color: AppColors.terra),
            const SizedBox(width: 6),
            Text(l10n.tagAddChip,
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
    this.onTap,
    this.editing = false,
    this.wiggle,
    this.wiggleIndex = 0,
    this.onDelete,
  });
  final CategoryRow category;
  final VoidCallback? onTap;

  /// Wiggle (edit) mode: the round icon shakes and shows a − delete badge.
  final bool editing;
  final Animation<double>? wiggle;
  final int wiggleIndex;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget glyph = CategoryGlyph(
      iconKey: category.iconKey,
      color: AppColors.forHex(category.colorHex),
      size: 52,
      radius: 16,
      iconSize: 24,
      circle: true,
    );
    if (editing && wiggle != null) {
      final anim = wiggle!;
      glyph = AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          final angle =
              math.sin(anim.value * 2 * math.pi + wiggleIndex * 0.9) * 0.05;
          return Transform.rotate(angle: angle, child: child);
        },
        child: glyph,
      );
    }
    // Badge overlaps the icon's top-left corner (kept inside the 52×52 box so it
    // stays tappable — hit-testing ignores anything outside the parent bounds).
    final icon = SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          glyph,
          if (editing && onDelete != null)
            Positioned(
              left: 0,
              top: 0,
              child: _DeleteBadge(onTap: onDelete!),
            ),
        ],
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 7),
          Flexible(
            child: Text(category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.body(size: 12, color: context.palette.ink2)),
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
    final l10n = AppLocalizations.of(context);
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
            child: Text(l10n.catAdd,
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

/// Manage-mode category grid. Long-pressing an icon enters an iOS-style wiggle
/// edit mode and immediately picks it up to drag; dropping it on another icon
/// reorders the grid. A − badge on each icon deletes it. Tapping (not editing)
/// renames; the dashed + tile adds a new category.
class _ManagedCategoryGrid extends StatefulWidget {
  const _ManagedCategoryGrid({
    required this.categories,
    required this.editing,
    required this.onEnterEdit,
    required this.onReorder,
    required this.onDelete,
    required this.onRename,
    required this.onAdd,
  });

  final List<CategoryRow> categories;
  final bool editing;
  final VoidCallback onEnterEdit;

  /// Persist the new full order (category ids, first to last).
  final void Function(List<String> idsInOrder) onReorder;
  final Future<void> Function(CategoryRow category) onDelete;
  final void Function(CategoryRow category) onRename;
  final VoidCallback onAdd;

  @override
  State<_ManagedCategoryGrid> createState() => _ManagedCategoryGridState();
}

class _ManagedCategoryGridState extends State<_ManagedCategoryGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..repeat();

  // A local working copy so a drop reorders instantly; re-synced from the
  // provider only when the set of categories changes (an add/delete).
  late List<CategoryRow> _items = [...widget.categories];

  @override
  void didUpdateWidget(_ManagedCategoryGrid old) {
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

  void _move(int from, int to) {
    if (from == to || from < 0 || to < 0) return;
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
    });
    widget.onReorder(_items.map((c) => c.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 18,
      crossAxisSpacing: 4,
      childAspectRatio: 0.78,
      children: [
        for (var i = 0; i < _items.length; i++) _cell(i, _items[i], editing),
        if (!editing) _AddCategoryButton(onTap: widget.onAdd),
      ],
    );
  }

  Widget _cell(int index, CategoryRow category, bool editing) {
    final tile = _CategoryButton(
      category: category,
      editing: editing,
      wiggle: _wiggle,
      wiggleIndex: index,
      onTap: editing ? null : () => widget.onRename(category),
      onDelete: editing ? () => widget.onDelete(category) : null,
    );

    // Long-press picks the icon up; the first grab also flips on edit mode.
    final draggable = LongPressDraggable<int>(
      data: index,
      onDragStarted: () {
        if (!editing) widget.onEnterEdit();
      },
      feedback: _DragFeedback(category: category),
      childWhenDragging: Opacity(opacity: 0.25, child: tile),
      child: tile,
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _move(d.data, index),
      builder: (context, candidate, rejected) => AnimatedScale(
        scale: candidate.isNotEmpty ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: draggable,
      ),
    );
  }
}

/// The lifted icon shown under the finger while dragging (iOS-style).
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.category});
  final CategoryRow category;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: 1.15,
        child: CategoryGlyph(
          iconKey: category.iconKey,
          color: AppColors.forHex(category.colorHex),
          size: 52,
          radius: 16,
          iconSize: 24,
          circle: true,
        ),
      ),
    );
  }
}

/// Red − badge on a wiggling icon; tap to delete that category.
class _DeleteBadge extends StatelessWidget {
  const _DeleteBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.reverse, width: 1.5),
        ),
        child: const Icon(AppIcons.minus, size: 13, color: Colors.white),
      ),
    );
  }
}
