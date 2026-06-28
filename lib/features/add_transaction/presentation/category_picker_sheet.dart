import 'package:flutter/material.dart';

import '../../../core/widgets/sheet_scaffold.dart';
import '../../../domain/enums/enums.dart';
import '../../categories/presentation/category_tag_board.dart';

/// Result of the category/tag picker.
class CategoryPick {
  const CategoryPick(this.categoryId, this.tagIds);
  final String categoryId;
  final List<String> tagIds;
}

/// Bottom sheet wrapper around [CategoryTagBoard] in select mode: tag chips +
/// a category grid. Tapping a category returns the chosen category plus the
/// currently selected tags.
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    super.key,
    this.initialTagIds = const [],
    this.categoryType = CategoryType.expense,
  });

  final List<String> initialTagIds;
  final CategoryType categoryType;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'เลือกหมวดหมู่ / แท็ก',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: CategoryTagBoard(
          categoryType: categoryType,
          initialTagIds: initialTagIds,
          onPick: (categoryId, tagIds) =>
              Navigator.of(context).pop(CategoryPick(categoryId, tagIds)),
        ),
      ),
    );
  }
}
