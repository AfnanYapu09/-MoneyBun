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

  /// The default "main" expense categories — the ones an ordinary Thai user
  /// reaches for daily. Each uses a Bun pixel-art glyph (`iconKey` == the
  /// glyph id in `pixel_icons_data.dart`) and its design accent colour. The
  /// list index becomes each category's `sortOrder`. The full ~100-icon set is
  /// reachable from the "+ เพิ่ม" icon picker. `sys_other` is kept last as the
  /// stats "อื่นๆ" bucket (hidden from the picker). Stable `sys_` ids keep
  /// re-seeding/sync idempotent; ids carried over from earlier versions are
  /// re-skinned to pixel glyphs by the v5 migration.
  static const List<CategorySeed> categories = [
    CategorySeed(
        id: 'sys_food',
        nameTh: 'อาหาร',
        nameEn: 'Food',
        iconKey: 'food',
        colorHex: 'FFC77E5E'),
    CategorySeed(
        id: 'sys_coffee',
        nameTh: 'กาแฟ ชานม',
        nameEn: 'Coffee & Tea',
        iconKey: 'coffee',
        colorHex: 'FFA8845F'),
    CategorySeed(
        id: 'sys_groceries',
        nameTh: 'ของสด ตลาด',
        nameEn: 'Groceries',
        iconKey: 'groceries',
        colorHex: 'FF8FA877'),
    CategorySeed(
        id: 'sys_snacks',
        nameTh: 'ขนม ของหวาน',
        nameEn: 'Snacks',
        iconKey: 'snacks',
        colorHex: 'FFCD8A84'),
    CategorySeed(
        id: 'sys_transport',
        nameTh: 'เดินทาง',
        nameEn: 'Transport',
        iconKey: 'transport',
        colorHex: 'FF7CA39B'),
    CategorySeed(
        id: 'sys_taxi',
        nameTh: 'แท็กซี่ วิน',
        nameEn: 'Taxi & Ride',
        iconKey: 'taxi',
        colorHex: 'FFCCA968'),
    CategorySeed(
        id: 'sys_fuel',
        nameTh: 'น้ำมันรถ',
        nameEn: 'Fuel',
        iconKey: 'fuel',
        colorHex: 'FFCB7C6F'),
    CategorySeed(
        id: 'sys_shopping',
        nameTh: 'ช้อปปิ้ง',
        nameEn: 'Shopping',
        iconKey: 'shopping',
        colorHex: 'FFA87E91'),
    CategorySeed(
        id: 'sys_clothes',
        nameTh: 'เสื้อผ้า',
        nameEn: 'Clothes',
        iconKey: 'clothes',
        colorHex: 'FFCD8A84'),
    CategorySeed(
        id: 'sys_home',
        nameTh: 'ของใช้ในบ้าน',
        nameEn: 'Home',
        iconKey: 'home',
        colorHex: 'FF7CA39B'),
    CategorySeed(
        id: 'sys_bills',
        nameTh: 'บิล ค่าน้ำไฟ',
        nameEn: 'Bills',
        iconKey: 'bills',
        colorHex: 'FF849ABA'),
    CategorySeed(
        id: 'sys_phone',
        nameTh: 'มือถือ เน็ต',
        nameEn: 'Phone & Net',
        iconKey: 'phone',
        colorHex: 'FF849ABA'),
    CategorySeed(
        id: 'sys_health',
        nameTh: 'สุขภาพ',
        nameEn: 'Health',
        iconKey: 'health',
        colorHex: 'FFCB7C6F'),
    CategorySeed(
        id: 'sys_beauty',
        nameTh: 'ความงาม',
        nameEn: 'Beauty',
        iconKey: 'beauty',
        colorHex: 'FFCD8A84'),
    CategorySeed(
        id: 'sys_entertainment',
        nameTh: 'บันเทิง เกม',
        nameEn: 'Entertainment',
        iconKey: 'game',
        colorHex: 'FF9A8AAD'),
    CategorySeed(
        id: 'sys_education',
        nameTh: 'การศึกษา',
        nameEn: 'Education',
        iconKey: 'education',
        colorHex: 'FF849ABA'),
    CategorySeed(
        id: 'sys_family',
        nameTh: 'ครอบครัว',
        nameEn: 'Family',
        iconKey: 'family',
        colorHex: 'FFC77E5E'),
    CategorySeed(
        id: 'sys_pet',
        nameTh: 'สัตว์เลี้ยง',
        nameEn: 'Pet',
        iconKey: 'pet',
        colorHex: 'FFA8845F'),
    CategorySeed(
        id: 'sys_donate',
        nameTh: 'ทำบุญ บริจาค',
        nameEn: 'Merit & Donate',
        iconKey: 'merit',
        colorHex: 'FFCD8A84'),
    CategorySeed(
        id: 'sys_housing',
        nameTh: 'ค่าเช่า หอพัก',
        nameEn: 'Rent',
        iconKey: 'housing',
        colorHex: 'FFCBA068'),
    CategorySeed(
        id: 'sys_subscription',
        nameTh: 'ค่าสมาชิก',
        nameEn: 'Subscriptions',
        iconKey: 'subscription',
        colorHex: 'FF9A8AAD'),
    CategorySeed(
        id: 'sys_other',
        nameTh: 'อื่นๆ',
        nameEn: 'Other',
        iconKey: 'misc',
        colorHex: 'FFA8845F'),
  ];

  /// Income categories — the basics for everyday money in. `type: income`.
  /// Stable `sys_inc_` ids keep re-seeding/sync idempotent.
  static const List<CategorySeed> incomeCategories = [
    CategorySeed(
        id: 'sys_inc_salary',
        nameTh: 'เงินเดือน',
        nameEn: 'Salary',
        iconKey: 'salary',
        colorHex: 'FF8FA877',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_bonus',
        nameTh: 'โบนัส',
        nameEn: 'Bonus',
        iconKey: 'bonus',
        colorHex: 'FFCCA968',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_freelance',
        nameTh: 'รายได้เสริม',
        nameEn: 'Freelance',
        iconKey: 'freelance',
        colorHex: 'FF8FA877',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_sale',
        nameTh: 'ค้าขาย',
        nameEn: 'Sales',
        iconKey: 'business',
        colorHex: 'FFCBA068',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_invest',
        nameTh: 'หุ้น ปันผล',
        nameEn: 'Investment',
        iconKey: 'invest',
        colorHex: 'FF8FA877',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_gift',
        nameTh: 'ของขวัญ อั่งเปา',
        nameEn: 'Gifts',
        iconKey: 'angpao',
        colorHex: 'FFCB7C6F',
        type: CategoryType.income),
    CategorySeed(
        id: 'sys_inc_refund',
        nameTh: 'เงินคืน',
        nameEn: 'Refund',
        iconKey: 'refund',
        colorHex: 'FF8FA877',
        type: CategoryType.income),
  ];
}
