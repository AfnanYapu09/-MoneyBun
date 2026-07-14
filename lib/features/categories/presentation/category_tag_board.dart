import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/category_l10n.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/utils/disposal.dart';

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
          widget.manage
              // Manage mode: long-press a chip for the same wiggle edit mode
              // as categories — drag to reorder, − badge to delete.
              ? _ManagedTagWrap(
                  tags: tags,
                  showHint: !widget.showCategories,
                  onRename: _editTag,
                  onDelete: _confirmDeleteTag,
                  onReorder: (ids) =>
                      ref.read(tagRepositoryProvider).reorder(ids),
                  onAdd: _addTag,
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const _TagHashBadge(),
                    for (final t in tags)
                      _TagChip(
                        label: t.name,
                        selected: _tags.contains(t.id),
                        onTap: () => setState(
                          () => _tags.contains(t.id)
                              ? _tags.remove(t.id)
                              : _tags.add(t.id),
                        ),
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
                    child: Text(
                      l10n.catReorderHint,
                      style: AppTypography.body(
                        size: 13,
                        color: context.palette.ink3,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _editing = false),
                    child: Text(
                      l10n.catDone,
                      style: AppTypography.heading(
                        size: 15,
                        weight: FontWeight.w600,
                        color: AppColors.terra,
                      ),
                    ),
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
                child: Text(
                  l10n.catLongPressHint,
                  style: AppTypography.body(
                    size: 12.5,
                    color: context.palette.ink3,
                  ),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Future<void> _confirmDeleteCategory(CategoryRow c) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    // Captured before the await: the auth-state redirect can unmount this
    // board while the dialog is up, after which ref.read throws.
    final repo = ref.read(categoryRepositoryProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.catConfirmDelete(c.displayName(locale))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: context.palette.dangerFg),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.delete(c.id);
    }
  }

  void _addCategory() =>
      showAddCategorySheet(context, type: widget.categoryType);

  Future<void> _editCategory(CategoryRow c) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final repo = ref.read(categoryRepositoryProvider);
    final controller = TextEditingController(text: c.displayName(locale));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catRenameTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    disposeAfterRouteExit(controller);
    if (name != null && name.isNotEmpty) {
      await repo.rename(c.id, name, english: locale.startsWith('en'));
    }
  }

  Future<void> _addTag() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(tagRepositoryProvider);
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
            onPressed: () => Navigator.pop(c),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(l10n.catAdd),
          ),
        ],
      ),
    );
    disposeAfterRouteExit(controller);
    if (name != null && name.isNotEmpty) {
      final id = await repo.save(name: name);
      if (mounted && !widget.manage) setState(() => _tags.add(id));
    }
  }

  Future<void> _confirmDeleteTag(TagRow t) async {
    final l10n = AppLocalizations.of(context);
    // Captured before the await, same as _confirmDeleteCategory above.
    final repo = ref.read(tagRepositoryProvider);
    final ok = await confirmDeleteTxn(
      context,
      title: l10n.tagEditTitle,
      body: l10n.tagConfirmDelete(t.name),
    );
    if (ok) await repo.delete(t.id);
  }

  Future<void> _editTag(TagRow t) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(tagRepositoryProvider);
    final controller = TextEditingController(text: t.name);
    // Rename only — deleting a tag lives in the wiggle edit mode's − badge.
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tagEditTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    disposeAfterRouteExit(controller);
    if (action == null || action.isEmpty) return;
    await repo.save(
      id: t.id,
      name: action,
      colorHex: t.colorHex,
      sortOrder: t.sortOrder,
    );
  }
}

/// The leading "#" tile in front of the tag chips.
class _TagHashBadge extends StatelessWidget {
  const _TagHashBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: context.palette.terraWash,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(AppIcons.hash, size: 17, color: context.palette.terraFg),
    );
  }
}

/// Manage-mode tag chips: the same iOS-style wiggle edit mode as the category
/// grid — long-press a chip to pick it up (entering edit mode), drop it on
/// another chip to reorder, tap the − badge to delete, tap a chip to rename.
class _ManagedTagWrap extends StatefulWidget {
  const _ManagedTagWrap({
    required this.tags,
    required this.showHint,
    required this.onRename,
    required this.onDelete,
    required this.onReorder,
    required this.onAdd,
  });

  final List<TagRow> tags;

  /// Show the long-press hint (manage-tags screen only, where the chips are
  /// the whole page).
  final bool showHint;
  final void Function(TagRow tag) onRename;
  final Future<void> Function(TagRow tag) onDelete;
  final void Function(List<String> idsInOrder) onReorder;
  final VoidCallback onAdd;

  @override
  State<_ManagedTagWrap> createState() => _ManagedTagWrapState();
}

class _ManagedTagWrapState extends State<_ManagedTagWrap>
    with SingleTickerProviderStateMixin {
  // Created in initState — a lazy `late final` would be touched for the first
  // time inside dispose() when the widget never built a chip, and creating a
  // ticker during unmount crashes.
  late final AnimationController _wiggle;

  bool _editing = false;

  // Local working copy so a drop reorders instantly; refreshed from the
  // provider while preserving the local order (renames flow through, adds
  // append, deletes drop out).
  late List<TagRow> _items = [...widget.tags];

  @override
  void initState() {
    super.initState();
    // NOT repeat()ed here: the ticker runs only while edit mode is active
    // (see _setEditing) — repeating for the screen's whole life kept a 60fps
    // ticker busy even when nothing wiggled.
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  void _setEditing(bool v) {
    if (_editing == v) return;
    setState(() => _editing = v);
    if (v) {
      _wiggle.repeat();
    } else {
      _wiggle
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(_ManagedTagWrap old) {
    super.didUpdateWidget(old);
    final byId = {for (final t in widget.tags) t.id: t};
    final kept = [
      for (final t in _items)
        if (byId.containsKey(t.id)) byId.remove(t.id)!,
    ];
    _items = [...kept, ...byId.values];
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
    widget.onReorder(_items.map((t) => t.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_editing)
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.catReorderHint,
                  style: AppTypography.body(
                    size: 13,
                    color: context.palette.ink3,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _setEditing(false),
                child: Text(
                  l10n.catDone,
                  style: AppTypography.heading(
                    size: 15,
                    weight: FontWeight.w600,
                    color: AppColors.terra,
                  ),
                ),
              ),
            ],
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _TagHashBadge(),
            for (var i = 0; i < _items.length; i++) _cell(i, _items[i]),
            if (!_editing) _AddTagChip(onAdd: widget.onAdd),
          ],
        ),
        if (widget.showHint && !_editing) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              l10n.tagLongPressHint,
              style: AppTypography.body(
                size: 12.5,
                color: context.palette.ink3,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _cell(int index, TagRow tag) {
    final chip = _TagChip(
      label: tag.name,
      selected: false,
      onTap: _editing ? null : () => widget.onRename(tag),
      editing: _editing,
      wiggle: _wiggle,
      wiggleIndex: index,
      onDelete: _editing ? () => widget.onDelete(tag) : null,
    );

    final draggable = LongPressDraggable<int>(
      data: index,
      onDragStarted: () => _setEditing(true),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.1,
          child: _TagChip(label: tag.name, selected: true, onTap: null),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: chip),
      child: chip,
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _move(d.data, index),
      builder: (context, candidate, rejected) => AnimatedScale(
        scale: candidate.isNotEmpty ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: draggable,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.editing = false,
    this.wiggle,
    this.wiggleIndex = 0,
    this.onDelete,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Wiggle (edit) mode: the chip shakes and shows a − delete badge.
  final bool editing;
  final Animation<double>? wiggle;
  final int wiggleIndex;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget chip = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.terra : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: selected ? AppColors.terra : context.palette.line,
          width: 1.5,
        ),
      ),
      // Center(widthFactor: 1) keeps the chip hugging its text — a plain
      // `alignment:` on the Container would stretch it to the Wrap's full
      // width, stacking one chip per line.
      child: Center(
        widthFactor: 1,
        child: Text(
          '#$label',
          style: AppTypography.heading(
            size: 14,
            weight: FontWeight.w500,
            color: selected ? AppColors.reverse : context.palette.ink,
          ),
        ),
      ),
    );
    if (editing && wiggle != null) {
      final anim = wiggle!;
      chip = AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          final angle =
              math.sin(anim.value * 2 * math.pi + wiggleIndex * 0.9) * 0.03;
          return Transform.rotate(angle: angle, child: child);
        },
        child: chip,
      );
    }
    if (editing && onDelete != null) {
      chip = Stack(
        clipBehavior: Clip.none,
        children: [
          chip,
          Positioned(left: -6, top: -6, child: _DeleteBadge(onTap: onDelete!)),
        ],
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: chip,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: context.palette.line, width: 1.5),
        ),
        child: Center(
          widthFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.plus, size: 16, color: AppColors.terra),
              const SizedBox(width: 6),
              Text(
                l10n.tagAddChip,
                style: AppTypography.heading(size: 14, weight: FontWeight.w400),
              ),
            ],
          ),
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
    final locale = Localizations.localeOf(context).languageCode;
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
            Positioned(left: 0, top: 0, child: _DeleteBadge(onTap: onDelete!)),
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
            child: Text(
              category.displayName(locale),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 12, color: context.palette.ink2),
            ),
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
            child: Text(
              l10n.catAdd,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 12, color: AppColors.terra),
            ),
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
  // Created in initState — see _ManagedTagWrapState._wiggle for why lazy
  // initialization here is unsafe.
  late final AnimationController _wiggle;

  // A local working copy so a drop reorders instantly; re-synced from the
  // provider only when the set of categories changes (an add/delete).
  late List<CategoryRow> _items = [...widget.categories];

  @override
  void initState() {
    super.initState();
    // Runs only while edit mode is active — see didUpdateWidget.
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    if (widget.editing) _wiggle.repeat();
  }

  @override
  void didUpdateWidget(_ManagedCategoryGrid old) {
    super.didUpdateWidget(old);
    if (widget.editing != old.editing) {
      if (widget.editing) {
        _wiggle.repeat();
      } else {
        _wiggle
          ..stop()
          ..value = 0;
      }
    }
    final incoming = widget.categories.map((c) => c.id).toSet();
    final current = _items.map((c) => c.id).toSet();
    if (incoming.length != current.length || !incoming.containsAll(current)) {
      _items = [...widget.categories];
      return;
    }
    // Same id set: refresh each row's CONTENT (a rename here, or an edit that
    // arrived via sync) while preserving the local drag order — otherwise the
    // tiles keep showing the old name until something is added or deleted.
    final byId = {for (final c in widget.categories) c.id: c};
    _items = [for (final c in _items) byId[c.id] ?? c];
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
