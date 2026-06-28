import '../../domain/enums/enums.dart';

/// A category definition used to seed the database on first run.
class CategorySeed {
  const CategorySeed({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.iconKey,
    required this.colorHex,
    this.type = CategoryType.expense,
  });

  final String id;
  final String nameTh;
  final String nameEn;

  /// Key resolved to an [IconData] by `CategoryIcons` in the presentation layer.
  final String iconKey;
  final String colorHex;

  /// Income or expense. Defaults to expense (slip imports are money out).
  final CategoryType type;
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
        id: 'sys_coffee',
        nameTh: 'คาเฟ่, กาแฟ',
        nameEn: 'Cafe',
        iconKey: 'coffee',
        colorHex: 'FFA9744F'),
    CategorySeed(
        id: 'sys_subscription',
        nameTh: 'ค่าบริการรายเดือน',
        nameEn: 'Subscriptions',
        iconKey: 'subscription',
        colorHex: 'FF566AC2'),
    CategorySeed(
        id: 'sys_beauty',
        nameTh: 'ความงาม',
        nameEn: 'Beauty',
        iconKey: 'beauty',
        colorHex: 'FFD86592'),
    CategorySeed(
        id: 'sys_insurance',
        nameTh: 'ประกัน',
        nameEn: 'Insurance',
        iconKey: 'insurance',
        colorHex: 'FF4E8C8A'),
    CategorySeed(
        id: 'sys_debt',
        nameTh: 'ผ่อน, หนี้',
        nameEn: 'Debt',
        iconKey: 'debt',
        colorHex: 'FFC0533F'),
    CategorySeed(
        id: 'sys_donate',
        nameTh: 'บริจาค, ทำบุญ',
        nameEn: 'Donate',
        iconKey: 'donate',
        colorHex: 'FFCB5A75'),
    CategorySeed(
        id: 'sys_other',
        nameTh: 'อื่นๆ',
        nameEn: 'Other',
        iconKey: 'other',
        colorHex: 'FF7A736B'),
  ];

  /// Income categories — the basics for everyday money in. `type: income`.
  /// Stable `sys_inc_` ids keep re-seeding/sync idempotent.
  static const List<CategorySeed> incomeCategories = [
    CategorySeed(
        id: 'sys_inc_salary',
        nameTh: 'เงินเดือน',
        nameEn: 'Salary',
        iconKey: 'salary',
        colorHex: 'FF4FA36B',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_bonus',
        nameTh: 'โบนัส',
        nameEn: 'Bonus',
        iconKey: 'bonus',
        colorHex: 'FFD9A441',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_freelance',
        nameTh: 'รายได้เสริม, ฟรีแลนซ์',
        nameEn: 'Freelance',
        iconKey: 'work',
        colorHex: 'FF3FA9A0',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_invest',
        nameTh: 'ดอกเบี้ย, เงินปันผล',
        nameEn: 'Investment',
        iconKey: 'invest',
        colorHex: 'FF3D7DCA',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_sale',
        nameTh: 'ขายของ',
        nameEn: 'Sales',
        iconKey: 'sale',
        colorHex: 'FFB5531A',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_gift',
        nameTh: 'ได้รับ, ของขวัญ',
        nameEn: 'Gifts',
        iconKey: 'gift',
        colorHex: 'FFB5739E',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_refund',
        nameTh: 'เงินคืน',
        nameEn: 'Refund',
        iconKey: 'refund',
        colorHex: 'FF6E8B6F',
        type: CategoryType.income),
  ];
}
