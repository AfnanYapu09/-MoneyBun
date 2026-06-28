import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../categories/presentation/category_tag_board.dart';
import '../../transactions/presentation/widgets/account_flow.dart';

/// Result of the category/tag picker.
class CategoryPick {
  const CategoryPick(this.categoryId, this.tagIds);
  final String categoryId;
  final List<String> tagIds;
}

/// Bottom sheet wrapper around [CategoryTagBoard] in select mode: tag chips +
/// a category grid. Tapping a category returns the chosen category plus the
/// currently selected tags.
///
/// When categorising a slip-backed entry, pass [slip] to show a "ดูสลิป" button
/// and [onTransfer] to show a "ย้ายเงิน" button (reclassify as a transfer).
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    super.key,
    this.initialTagIds = const [],
    this.categoryType = CategoryType.expense,
    this.slip,
    this.onTransfer,
  });

  final List<String> initialTagIds;
  final CategoryType categoryType;

  /// The original slip, if this entry came from one — enables "ดูสลิป".
  final SlipRow? slip;

  /// Reclassify-as-transfer action — enables "ย้ายเงิน".
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    final hasActions = slip != null || onTransfer != null;
    return SheetScaffold(
      title: 'เลือกหมวดหมู่ / แท็ก',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasActions) ...[
              Row(
                children: [
                  if (slip != null)
                    Expanded(
                      child: _ActionButton(
                        icon: AppIcons.receiptText,
                        label: 'ดูสลิป',
                        onTap: () => showSlipViewer(context, slip!),
                      ),
                    ),
                  if (slip != null && onTransfer != null)
                    const SizedBox(width: 10),
                  if (onTransfer != null)
                    Expanded(
                      child: _ActionButton(
                        icon: AppIcons.arrowLeftRight,
                        label: 'ย้ายเงิน',
                        onTap: () {
                          onTransfer!();
                          Navigator.of(context).maybePop();
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            CategoryTagBoard(
              categoryType: categoryType,
              initialTagIds: initialTagIds,
              onPick: (categoryId, tagIds) =>
                  Navigator.of(context).pop(CategoryPick(categoryId, tagIds)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.terra700),
            const SizedBox(width: 8),
            Text(label,
                style: AppTypography.heading(
                    size: 14.5, weight: FontWeight.w500, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
