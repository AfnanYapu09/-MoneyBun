import '../../domain/enums/enums.dart';

/// A category definition used to seed the database on first run.
class CategorySeed {
  const CategorySeed({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.type,
    required this.iconKey,
    required this.colorHex,
  });

  final String id;
  final String nameTh;
  final String nameEn;
  final CategoryType type;

  /// Key resolved to an [IconData] by `CategoryIcons` in the presentation layer.
  final String iconKey;
  final String colorHex;
}

/// An opening wallet seeded on first run so the app is usable immediately.
class AccountSeed {
  const AccountSeed({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.type,
    required this.colorHex,
    this.bankCode,
  });

  final String id;
  final String nameTh;
  final String nameEn;
  final AccountType type;
  final String colorHex;
  final String? bankCode;
}

class SeedData {
  const SeedData._();

  /// Stable ids (prefixed `sys_`) so re-seeding and sync stay idempotent.
  static const List<CategorySeed> categories = [
    CategorySeed(
        id: 'sys_food',
        nameTh: 'อาหาร',
        nameEn: 'Food',
        type: CategoryType.expense,
        iconKey: 'food',
        colorHex: 'FFE8732C'),
    CategorySeed(
        id: 'sys_shopping',
        nameTh: 'ช้อปปิ้ง',
        nameEn: 'Shopping',
        type: CategoryType.expense,
        iconKey: 'shopping',
        colorHex: 'FFD9476B'),
    CategorySeed(
        id: 'sys_education',
        nameTh: 'การศึกษา',
        nameEn: 'Education',
        type: CategoryType.expense,
        iconKey: 'education',
        colorHex: 'FF3D7DCA'),
    CategorySeed(
        id: 'sys_home',
        nameTh: 'บ้าน/ค่าน้ำค่าไฟ',
        nameEn: 'Home/Utilities',
        type: CategoryType.expense,
        iconKey: 'home',
        colorHex: 'FF4FA36B'),
    CategorySeed(
        id: 'sys_transport',
        nameTh: 'เดินทาง',
        nameEn: 'Transport',
        type: CategoryType.expense,
        iconKey: 'transport',
        colorHex: 'FF8A6DBF'),
    CategorySeed(
        id: 'sys_health',
        nameTh: 'สุขภาพ',
        nameEn: 'Health',
        type: CategoryType.expense,
        iconKey: 'health',
        colorHex: 'FFC0533F'),
    CategorySeed(
        id: 'sys_entertainment',
        nameTh: 'บันเทิง',
        nameEn: 'Entertainment',
        type: CategoryType.expense,
        iconKey: 'entertainment',
        colorHex: 'FFB5531A'),
    CategorySeed(
        id: 'sys_other_expense',
        nameTh: 'อื่นๆ',
        nameEn: 'Other',
        type: CategoryType.expense,
        iconKey: 'other',
        colorHex: 'FF7A736B'),
    CategorySeed(
        id: 'sys_salary',
        nameTh: 'เงินเดือน',
        nameEn: 'Salary',
        type: CategoryType.income,
        iconKey: 'salary',
        colorHex: 'FF2E9E5B'),
    CategorySeed(
        id: 'sys_bonus',
        nameTh: 'โบนัส/รายได้พิเศษ',
        nameEn: 'Bonus/Extra',
        type: CategoryType.income,
        iconKey: 'bonus',
        colorHex: 'FF3FA9A0'),
    CategorySeed(
        id: 'sys_other_income',
        nameTh: 'รายรับอื่นๆ',
        nameEn: 'Other income',
        type: CategoryType.income,
        iconKey: 'other',
        colorHex: 'FF6FA86F'),
  ];

  static const List<AccountSeed> accounts = [
    AccountSeed(
        id: 'sys_cash',
        nameTh: 'เงินสด',
        nameEn: 'Cash',
        type: AccountType.cash,
        colorHex: 'FF4FA36B'),
    AccountSeed(
        id: 'sys_truemoney',
        nameTh: 'ทรูมันนี่',
        nameEn: 'TrueMoney',
        type: AccountType.ewallet,
        colorHex: 'FFE8732C',
        bankCode: 'TRUEMONEY'),
  ];
}
