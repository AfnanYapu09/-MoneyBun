import 'package:flutter/material.dart';

import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../categories/presentation/category_tag_board.dart';

/// Manage tags using the same tag-chip UI as the category picker (manage mode:
/// tap a chip to rename/delete, add chip to create).
class ManageTagsScreen extends StatelessWidget {
  const ManageTagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SubScreenScaffold(
      title: l10n.tagManageTitle,
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: CategoryTagBoard(
          categoryType: CategoryType.expense,
          manage: true,
          showCategories: false,
        ),
      ),
    );
  }
}
