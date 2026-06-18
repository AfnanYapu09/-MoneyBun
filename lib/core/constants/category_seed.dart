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

  /// One flat list shown when categorising a slip. Includes spending buckets
  /// plus the money-out types the user asked for: ให้ยืม (lend) and ย้ายเงิน
  /// (transfer/send). Stable `sys_` ids keep re-seeding/sync idempotent.
  static const List<CategorySeed> categories = [
    CategorySeed(
        id: 'sys_food',
        nameTh: 'อาหาร',
        nameEn: 'Food',
        iconKey: 'food',
        colorHex: 'FFE8732C'),
    CategorySeed(
        id: 'sys_shopping',
        nameTh: 'ช้อปปิ้ง',
        nameEn: 'Shopping',
        iconKey: 'shopping',
        colorHex: 'FFD9476B'),
    CategorySeed(
        id: 'sys_education',
        nameTh: 'การศึกษา',
        nameEn: 'Education',
        iconKey: 'education',
        colorHex: 'FF3D7DCA'),
    CategorySeed(
        id: 'sys_home',
        nameTh: 'บ้าน/ค่าน้ำค่าไฟ',
        nameEn: 'Home/Utilities',
        iconKey: 'home',
        colorHex: 'FF4FA36B'),
    CategorySeed(
        id: 'sys_transport',
        nameTh: 'เดินทาง',
        nameEn: 'Transport',
        iconKey: 'transport',
        colorHex: 'FF8A6DBF'),
    CategorySeed(
        id: 'sys_health',
        nameTh: 'สุขภาพ',
        nameEn: 'Health',
        iconKey: 'health',
        colorHex: 'FFC0533F'),
    CategorySeed(
        id: 'sys_entertainment',
        nameTh: 'บันเทิง',
        nameEn: 'Entertainment',
        iconKey: 'entertainment',
        colorHex: 'FFB5531A'),
    CategorySeed(
        id: 'sys_lend',
        nameTh: 'ให้ยืม',
        nameEn: 'Lend',
        iconKey: 'lend',
        colorHex: 'FF3FA9A0'),
    CategorySeed(
        id: 'sys_transfer',
        nameTh: 'ย้ายเงิน',
        nameEn: 'Transfer',
        iconKey: 'transfer',
        colorHex: 'FF3D7DCA'),
    CategorySeed(
        id: 'sys_other',
        nameTh: 'อื่นๆ',
        nameEn: 'Other',
        iconKey: 'other',
        colorHex: 'FF7A736B'),
  ];
}
