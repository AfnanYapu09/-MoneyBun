import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'category_tag_board.dart';

/// Manage categories using the very same grid + tag-chip board as the
/// transaction category picker (manage mode: tap to rename, add tile to create).
class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  CategoryType _tab = CategoryType.expense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SubScreenScaffold(
      title: l10n.manageCategories,
      action: IconButton(
        onPressed: () => showAddCategorySheet(context, type: _tab),
        icon: const Icon(AppIcons.plus, size: 22, color: AppColors.terra),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          SegmentedControl<CategoryType>(
            value: _tab,
            onChanged: (t) => setState(() => _tab = t),
            segments: [
              Segment(value: CategoryType.expense, label: l10n.expense),
              Segment(value: CategoryType.income, label: l10n.income),
            ],
          ),
          const SizedBox(height: 18),
          CategoryTagBoard(categoryType: _tab, manage: true),
        ],
      ),
    );
  }
}
