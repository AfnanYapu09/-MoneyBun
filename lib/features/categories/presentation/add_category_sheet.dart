import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

/// Add a category by simply picking a pixel-art icon — no colour or name step.
/// The chosen icon's Thai name + accent colour become the new category; it is
/// appended to the end of the list. Icons already in use are shown ticked and
/// are not selectable (tapping closes the sheet).
class AddCategorySheet extends ConsumerWidget {
  const AddCategorySheet({super.key, this.type = CategoryType.expense});
  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    // Icons already used by a (non-deleted) category of this type — so we don't
    // offer duplicates.
    final used = {
      for (final c in categories)
        if (c.type == type) c.iconKey,
    };
    final income = type == CategoryType.income;
    final options =
        kPixelIconCatalog.where((i) => i.income == income).toList();

    Future<void> add(PixelIconInfo info) async {
      // Append after the current highest sortOrder so it lands last.
      var maxOrder = -1;
      for (final c in categories) {
        if (c.sortOrder > maxOrder) maxOrder = c.sortOrder;
      }
      await ref.read(categoryRepositoryProvider).save(
            name: info.nameTh,
            nameEn: info.nameEn,
            type: type,
            iconKey: info.id,
            colorHex: info.colorHex,
            sortOrder: maxOrder + 1,
          );
      if (context.mounted) Navigator.of(context).pop(true);
    }

    return SheetScaffold(
      title: income ? 'เพิ่มหมวดรายรับ' : 'เพิ่มหมวดรายจ่าย',
      fullHeight: true,
      child: GridView.count(
        crossAxisCount: 4,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.74,
        children: [
          for (final info in options)
            _IconTile(
              info: info,
              added: used.contains(info.id),
              onTap: () => add(info),
            ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.info,
    required this.added,
    required this.onTap,
  });
  final PixelIconInfo info;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: added ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: added ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CategoryGlyph(
                  iconKey: info.id,
                  color: AppColors.forHex(info.colorHex),
                  size: 52,
                  radius: 16,
                  circle: true,
                ),
                if (added)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: _AddedBadge(),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Flexible(
              child: Text(info.nameTh,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 11.5, color: AppColors.ink2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddedBadge extends StatelessWidget {
  const _AddedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: AppColors.green,
        shape: BoxShape.circle,
      ),
      child: const Icon(AppIcons.check, size: 13, color: Colors.white),
    );
  }
}
