import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';

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
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.type == _tab)
        .toList();

    return SubScreenScaffold(
      title: 'จัดการหมวดหมู่',
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
            segments: const [
              Segment(value: CategoryType.expense, label: 'รายจ่าย'),
              Segment(value: CategoryType.income, label: 'รายรับ'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _CategoryRow(
                    category: categories[i],
                    onEdit: () => _rename(categories[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showAddCategorySheet(context, type: _tab),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.terra, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AppIcons.plus, size: 20, color: AppColors.terra),
                  const SizedBox(width: 8),
                  Text('เพิ่มหมวด…ใหม่',
                      style: AppTypography.heading(
                          size: 16,
                          weight: FontWeight.w500,
                          color: AppColors.terra)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(CategoryRow c) async {
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
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onEdit});
  final CategoryRow category;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(AppIcons.gripVertical, size: 18, color: AppColors.ink3),
          const SizedBox(width: 10),
          IconChip(
              icon: CategoryIcons.forKey(category.iconKey),
              size: 38,
              radius: 11,
              iconSize: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Text(category.name, style: AppTypography.body(size: 15)),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(AppIcons.pencil, size: 18, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}
