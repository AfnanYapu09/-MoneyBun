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
import '../../../l10n/generated/app_localizations.dart';

/// A labelled section of the icon picker, so icons are easy to find by topic.
/// Carries both a Thai and an English heading so the picker follows the app
/// language (see [_IconGroup.label]).
class _IconGroup {
  const _IconGroup(this.nameTh, this.nameEn, this.income, this.ids);
  final String nameTh;
  final String nameEn;
  final bool income;
  final List<String> ids;

  String label(String locale) => locale.startsWith('en') ? nameEn : nameTh;
}

/// Icon-picker sections. Order = display order. Every catalogue id appears in
/// exactly one group (84 expense across 15 groups, 19 income across 4).
const List<_IconGroup> _groups = [
  // ---- Expense ----
  _IconGroup('อาหาร & เครื่องดื่ม', 'Food & Drinks', false, [
    'food', 'coffee', 'groceries', 'rice', 'snacks', //
    'bakery', 'fruit', 'bbq', 'drinks', 'cigarette', 'waterdrink',
  ]),
  _IconGroup('เดินทาง & รถ', 'Transport & Car', false, [
    'transport',
    'taxi',
    'train',
    'boat',
    'bike',
    'fuel',
    'carcare',
    'parking',
  ]),
  _IconGroup('ช้อปปิ้ง & ของใช้ส่วนตัว', 'Shopping & Personal', false, [
    'shopping', 'clothes', 'shoes', 'bag', 'glasses', //
    'watch', 'flowers', 'souvenir', 'parcel',
  ]),
  _IconGroup('ความงาม & ดูแลตัวเอง', 'Beauty & Self-care', false, [
    'beauty',
    'haircut',
    'nails',
    'spa',
    'laundry',
  ]),
  _IconGroup('บ้าน & ที่พัก', 'Home & Living', false, [
    'home', 'furniture', 'kitchenware', 'cleaning', //
    'repair', 'plant', 'condofee', 'housing',
  ]),
  _IconGroup('บิล & สาธารณูปโภค', 'Bills & Utilities', false, [
    'bills',
    'water',
    'electric',
    'gas',
    'phone',
    'topup',
    'subscription',
  ]),
  _IconGroup('อุปกรณ์ & ไอที', 'Devices & IT', false, [
    'electronics',
    'computer',
    'camera',
  ]),
  _IconGroup('สุขภาพ', 'Health', false, [
    'health',
    'pharmacy',
    'dentist',
    'supplement',
    'fitness',
    'sports',
  ]),
  _IconGroup('บันเทิง', 'Entertainment', false, [
    'game',
    'movies',
    'music',
    'hobby',
  ]),
  _IconGroup('ท่องเที่ยว', 'Travel', false, [
    'travel',
    'flight',
    'hotel',
    'lottery',
  ]),
  _IconGroup('การศึกษา', 'Education', false, [
    'education',
    'course',
    'books',
    'stationery',
  ]),
  _IconGroup('ครอบครัว & สัตว์เลี้ยง', 'Family & Pets', false, [
    'kids',
    'toys',
    'family',
    'pet',
    'vet',
  ]),
  _IconGroup('การเงิน & ภาระ', 'Finance & Obligations', false, [
    'insurance',
    'tax',
    'fine',
    'debt',
  ]),
  _IconGroup('บุญ & ความเชื่อ', 'Merit & Beliefs', false, [
    'merit',
    'ceremony',
    'funeral',
    'amulet',
    'fortune',
  ]),
  _IconGroup('อื่นๆ', 'Other', false, ['misc']),
  // ---- Income ----
  _IconGroup('งาน & เงินเดือน', 'Work & Salary', true, [
    'salary',
    'freelance',
    'business',
    'assetsale',
    'rental',
  ]),
  _IconGroup('โบนัส & พิเศษ', 'Bonus & Extra', true, [
    'bonus',
    'overtime',
    'commission',
    'tip',
  ]),
  _IconGroup('ลงทุน & ดอกเบี้ย', 'Investment & Interest', true, [
    'interest',
    'pension',
    'invest',
    'gold',
    'savings',
  ]),
  _IconGroup('ได้รับ & อื่นๆ', 'Received & Other', true, [
    'prize',
    'refund',
    'angpao',
    'welfare',
    'loan',
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
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
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
      title: income ? l10n.catAddIncomeTitle : l10n.catAddExpenseTitle,
      fullHeight: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
              child: Text(
                g.label(locale),
                style: AppTypography.heading(
                  size: 14,
                  weight: FontWeight.w600,
                  color: context.palette.ink2,
                ),
              ),
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
                  const Positioned(right: -2, bottom: -2, child: _AddedBadge()),
              ],
            ),
            const SizedBox(height: 7),
            Flexible(
              child: Text(
                Localizations.localeOf(context).languageCode.startsWith('en')
                    ? info.nameEn
                    : info.nameTh,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 11.5,
                  color: context.palette.ink2,
                ),
              ),
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
      decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
      child: const Icon(AppIcons.check, size: 13, color: Colors.white),
    );
  }
}
