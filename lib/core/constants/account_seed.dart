import '../../domain/enums/enums.dart';

/// A default account/wallet seeded on first run so the Accounts sheet (which
/// banks MoneyBun watches for slips) and the Add-transaction account pickers
/// have content. Stable `sys_acc_` ids keep re-seeding/sync idempotent.
class AccountSeed {
  const AccountSeed({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.type,
    required this.iconKey,
    required this.colorHex,
    this.bankCode,
  });

  final String id;
  final String nameTh;
  final String nameEn;
  final AccountType type;
  final String iconKey;
  final String colorHex; // ARGB hex (e.g. FF13A05F)
  final String? bankCode;
}

class AccountSeedData {
  const AccountSeedData._();

  static const List<AccountSeed> accounts = [
    AccountSeed(
        id: 'sys_acc_cash',
        nameTh: 'เงินสด',
        nameEn: 'Cash',
        type: AccountType.cash,
        iconKey: 'cash',
        colorHex: 'FF6E635A'),
    AccountSeed(
        id: 'sys_acc_kbank',
        nameTh: 'กสิกรไทย',
        nameEn: 'Kasikornbank',
        type: AccountType.bank,
        iconKey: 'sprout',
        colorHex: 'FF13A05F',
        bankCode: '004'),
    AccountSeed(
        id: 'sys_acc_truemoney',
        nameTh: 'ทรูมันนี่ วอลเล็ท',
        nameEn: 'TrueMoney Wallet',
        type: AccountType.ewallet,
        iconKey: 'wallet',
        colorHex: 'FFEF4923',
        bankCode: 'TRUEMONEY'),
    AccountSeed(
        id: 'sys_acc_ktb',
        nameTh: 'กรุงไทย',
        nameEn: 'Krungthai Bank',
        type: AccountType.bank,
        iconKey: 'landmark',
        colorHex: 'FF00A1E0',
        bankCode: '006'),
    AccountSeed(
        id: 'sys_acc_scb',
        nameTh: 'ไทยพาณิชย์',
        nameEn: 'Siam Commercial Bank',
        type: AccountType.bank,
        iconKey: 'gem',
        colorHex: 'FF4E2E7F',
        bankCode: '014'),
    AccountSeed(
        id: 'sys_acc_bbl',
        nameTh: 'กรุงเทพ',
        nameEn: 'Bangkok Bank',
        type: AccountType.bank,
        iconKey: 'droplet',
        colorHex: 'FF1A2F6E',
        bankCode: '002'),
    AccountSeed(
        id: 'sys_acc_ttb',
        nameTh: 'ทหารไทยธนชาต',
        nameEn: 'TMBThanachart',
        type: AccountType.bank,
        iconKey: 'building2',
        colorHex: 'FF00A0E2',
        bankCode: '011'),
  ];
}
