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

/// A labelled section of the icon picker, so icons are easy to find by topic.
class _IconGroup {
  const _IconGroup(this.nameTh, this.income, this.ids);
  final String nameTh;
  final bool income;
  final List<String> ids;
}

/// Icon-picker sections. Order = display order. Every catalogue id appears in
/// exactly one group (84 expense across 15 groups, 19 income across 4).
const List<_IconGroup> _groups = [
  // ---- Expense ----
  _IconGroup('อาหาร & เครื่องดื่ม', false, [
    'food', 'coffee', 'groceries', 'rice', 'snacks', //
    'bakery', 'fruit', 'bbq', 'drinks', 'cigarette', 'waterdrink',
  ]),
  _IconGroup('เดินทาง & รถ', false, [
    'transport', 'taxi', 'train', 'boat', 'bike', 'fuel', 'carcare', 'parking',
  ]),
  _IconGroup('ช้อปปิ้ง & ของใช้ส่วนตัว', false, [
    'shopping', 'clothes', 'shoes', 'bag', 'glasses', //
    'watch', 'flowers', 'souvenir', 'parcel',
  ]),
  _IconGroup('ความงาม & ดูแลตัวเอง', false, [
    'beauty', 'haircut', 'nails', 'spa', 'laundry',
  ]),
  _IconGroup('บ้าน & ที่พัก', false, [
    'home', 'furniture', 'kitchenware', 'cleaning', //
    'repair', 'plant', 'condofee', 'housing',
  ]),
  _IconGroup('บิล & สาธารณูปโภค', false, [
    'bills', 'water', 'electric', 'gas', 'phone', 'topup', 'subscription',
  ]),
  _IconGroup('อุปกรณ์ & ไอที', false, [
    'electronics', 'computer', 'camera',
  ]),
  _IconGroup('สุขภาพ', false, [
    'health', 'pharmacy', 'dentist', 'supplement', 'fitness', 'sports',
  ]),
  _IconGroup('บันเทิง', false, [
    'game', 'movies', 'music', 'hobby',
  ]),
  _IconGroup('ท่องเที่ยว', false, [
    'travel', 'flight', 'hotel', 'lottery',
  ]),
  _IconGroup('การศึกษา', false, [
    'education', 'course', 'books', 'stationery',
  ]),
  _IconGroup('ครอบครัว & สัตว์เลี้ยง', false, [
    'kids', 'toys', 'family', 'pet', 'vet',
  ]),
  _IconGroup('การเงิน & ภาระ', false, [
    'insurance', 'tax', 'fine', 'debt',
  ]),
  _IconGroup('บุญ & ความเชื่อ', false, [
    'merit', 'ceremony', 'funeral', 'amulet', 'fortune',
  ]),
  _IconGroup('อื่นๆ', false, [
    'misc',
  ]),
  // ---- Income ----
  _IconGroup('งาน & เงินเดือน', true, [
    'salary', 'freelance', 'business', 'assetsale', 'rental',
  ]),
  _IconGroup('โบนัส & พิเศษ', true, [
    'bonus', 'overtime', 'commission', 'tip',
  ]),
  _IconGroup('ลงทุน & ดอกเบี้ย', true, [
    'interest', 'pension', 'invest', 'gold', 'savings',
  ]),
  _IconGroup('ได้รับ & อื่นๆ', true, [
    'prize', 'refund', 'angpao', 'welfare', 'loan',
  ]),
];

/// Add a category by simply picking a pixel-art icon — no colour or name step.
/// Icons are grouped into labelled sections so they are easy to find. The
/// chosen icon's Thai name + accent colour become the new category, appended to
/// the end of the list. Icons already in use are shown ticked and not tappable.
class AddCategorySheet extends ConsumerWidget {
  const AddCategorySheet({super.key, this.type = CategoryType.expense});
  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    // Icons already used by a (non-deleted) category of this type.
    final used = {
      for (final c in categories)
        if (c.type == type) c.iconKey,
    };
    final catalog = {for (final i in kPixelIconCatalog) i.id: i};
    final income = type == CategoryType.income;
    final groups = _groups.where((g) => g.income == income);

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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
              child: Text(g.nameTh,
                  style: AppTypography.heading(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.ink2)),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              childAspectRatio: 0.74,
              children: [
                for (final id in g.ids)
                  if (catalog[id] case final info?)
                    _IconTile(
                      info: info,
                      added: used.contains(id),
                      onTap: () => add(info),
                    ),
              ],
            ),
          ],
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
