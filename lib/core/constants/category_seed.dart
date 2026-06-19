import '../../domain/enums/enums.dart';

/// A category definition used to seed the database on first run.
class CategorySeed {
  const CategorySeed({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.iconKey,
    required this.colorHex,
  });

  final String id;
  final String nameTh;
  final String nameEn;

  /// Key resolved to an [IconData] by `CategoryIcons` in the presentation layer.
  final String iconKey;
  final String colorHex;

  /// Every slip is money out, so categories are all "expense" kind.
  CategoryType get type => CategoryType.expense;
}

class SeedData {
  const SeedData._();

  /// The 12 spending categories from the design's category picker
  /// (`design_files/modals.jsx` CATS), in the same order — the list index
  /// becomes each category's `sortOrder`. `sys_other` is kept last as the stats
  /// "อื่นๆ" bucket (and is hidden from the picker). Stable `sys_` ids keep
  /// re-seeding/sync idempotent.
  static const List<CategorySeed> categories = [
    CategorySeed(
        id: 'sys_food',
        nameTh: 'อาหาร',
        nameEn: 'Food',
        iconKey: 'food',
        colorHex: 'FFE8732C'),
    CategorySeed(
        id: 'sys_transport',
        nameTh: 'เดินทาง, รถ',
        nameEn: 'Transport',
        iconKey: 'transport',
        colorHex: 'FF8A6DBF'),
    CategorySeed(
        id: 'sys_essentials',
        nameTh: 'ของใช้จำเป็น',
        nameEn: 'Essentials',
        iconKey: 'package',
        colorHex: 'FF6E8B6F'),
    CategorySeed(
        id: 'sys_shopping',
        nameTh: 'ช้อปปิ้ง',
        nameEn: 'Shopping',
        iconKey: 'shopping',
        colorHex: 'FFD9476B'),
    CategorySeed(
        id: 'sys_entertainment',
        nameTh: 'บันเทิง',
        nameEn: 'Entertainment',
        iconKey: 'entertainment',
        colorHex: 'FFB5531A'),
    CategorySeed(
        id: 'sys_home',
        nameTh: 'บ้าน, บิล',
        nameEn: 'Home & Bills',
        iconKey: 'home',
        colorHex: 'FF4FA36B'),
    CategorySeed(
        id: 'sys_health',
        nameTh: 'สุขภาพ',
        nameEn: 'Health',
        iconKey: 'health',
        colorHex: 'FFC0533F'),
    CategorySeed(
        id: 'sys_family',
        nameTh: 'ครอบครัว, สัตว์',
        nameEn: 'Family & Pets',
        iconKey: 'family',
        colorHex: 'FFB5739E'),
    CategorySeed(
        id: 'sys_lend',
        nameTh: 'ให้คนอื่น',
        nameEn: 'Give',
        iconKey: 'lend',
        colorHex: 'FF3FA9A0'),
    CategorySeed(
        id: 'sys_travel',
        nameTh: 'ท่องเที่ยว',
        nameEn: 'Travel',
        iconKey: 'travel',
        colorHex: 'FF2FA8C4'),
    CategorySeed(
        id: 'sys_education',
        nameTh: 'การศึกษา',
        nameEn: 'Education',
        iconKey: 'education',
        colorHex: 'FF3D7DCA'),
    CategorySeed(
        id: 'sys_work',
        nameTh: 'งาน, ธุรกิจ',
        nameEn: 'Work & Business',
        iconKey: 'work',
        colorHex: 'FF8A6D52'),
    CategorySeed(
        id: 'sys_other',
        nameTh: 'อื่นๆ',
        nameEn: 'Other',
        iconKey: 'other',
        colorHex: 'FF7A736B'),
  ];
}
