import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';

class ManageTagsScreen extends ConsumerStatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  ConsumerState<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends ConsumerState<ManageTagsScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).value ?? const <TagRow>[];
    final usage = ref.watch(tagUsageProvider).value ?? const <String, int>{};
    final sorted = [...tags]
      ..sort((a, b) => (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0));

    return SubScreenScaffold(
      title: 'จัดการแท็ก',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'เพิ่มแท็กใหม่'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child:
                    PrimaryButton(label: 'เพิ่ม', height: 50, onPressed: _add),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('ยังไม่มีแท็ก',
                  style: AppTypography.body(size: 14, color: AppColors.ink3)),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in sorted)
                  _TagChip(
                    label: t.name,
                    count: usage[t.id] ?? 0,
                    onRemove: () =>
                        ref.read(tagRepositoryProvider).delete(t.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await ref.read(tagRepositoryProvider).save(name: name);
    _controller.clear();
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.count,
    required this.onRemove,
  });
  final String label;
  final int count;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#$label',
              style: AppTypography.heading(size: 14, weight: FontWeight.w500)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text('$count',
                style: AppTypography.body(size: 12, color: AppColors.ink3)),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(AppIcons.x, size: 15, color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
