/// Thai bank registry. Codes are the 3-digit BOT/EMVCo bank codes that appear
/// in the Slip-Verify mini-QR. Used to validate a QR's bank code and to show a
/// bank's name for slips that already stored one. Banks are no longer detected
/// from OCR text (that was too noisy) — only the QR code is trusted.
class ThaiBank {
  const ThaiBank({
    required this.code,
    required this.nameTh,
    required this.nameEn,
    required this.shortName,
  });

  final String code;
  final String nameTh;
  final String nameEn;
  final String shortName;
}

class BankCodes {
  const BankCodes._();

  /// Special non-bank identifier for TrueMoney Wallet slips.
  static const String trueMoneyCode = 'TRUEMONEY';

  static const List<ThaiBank> all = [
    ThaiBank(
      code: '002',
      nameTh: 'ธนาคารกรุงเทพ',
      nameEn: 'Bangkok Bank',
      shortName: 'BBL',
    ),
    ThaiBank(
      code: '004',
      nameTh: 'ธนาคารกสิกรไทย',
      nameEn: 'Kasikornbank',
      shortName: 'KBANK',
    ),
    ThaiBank(
      code: '006',
      nameTh: 'ธนาคารกรุงไทย',
      nameEn: 'Krungthai Bank',
      shortName: 'KTB',
    ),
    ThaiBank(
      code: '011',
      nameTh: 'ธนาคารทหารไทยธนชาต',
      nameEn: 'TMBThanachart',
      shortName: 'TTB',
    ),
    ThaiBank(
      code: '014',
      nameTh: 'ธนาคารไทยพาณิชย์',
      nameEn: 'Siam Commercial Bank',
      shortName: 'SCB',
    ),
    ThaiBank(
      code: '025',
      nameTh: 'ธนาคารกรุงศรีอยุธยา',
      nameEn: 'Bank of Ayudhya',
      shortName: 'BAY',
    ),
    ThaiBank(
      code: '069',
      nameTh: 'ธนาคารเกียรตินาคินภัทร',
      nameEn: 'Kiatnakin Phatra',
      shortName: 'KKP',
    ),
    ThaiBank(
      code: '022',
      nameTh: 'ธนาคารซีไอเอ็มบีไทย',
      nameEn: 'CIMB Thai',
      shortName: 'CIMB',
    ),
    ThaiBank(
      code: '067',
      nameTh: 'ธนาคารทิสโก้',
      nameEn: 'TISCO Bank',
      shortName: 'TISCO',
    ),
    ThaiBank(
      code: '024',
      nameTh: 'ธนาคารยูโอบี',
      nameEn: 'UOB Thai',
      shortName: 'UOB',
    ),
    ThaiBank(
      code: '030',
      nameTh: 'ธนาคารออมสิน',
      nameEn: 'Government Savings Bank',
      shortName: 'GSB',
    ),
    ThaiBank(code: '034', nameTh: 'ธ.ก.ส.', nameEn: 'BAAC', shortName: 'BAAC'),
    ThaiBank(
      code: '035',
      nameTh: 'ธนาคารเพื่อการส่งออกฯ',
      nameEn: 'EXIM Bank',
      shortName: 'EXIM',
    ),
    ThaiBank(
      code: '073',
      nameTh: 'ธนาคารแลนด์ แอนด์ เฮ้าส์',
      nameEn: 'Land and Houses Bank',
      shortName: 'LHB',
    ),
    ThaiBank(
      code: trueMoneyCode,
      nameTh: 'ทรูมันนี่ วอลเล็ท',
      nameEn: 'TrueMoney Wallet',
      shortName: 'TrueMoney',
    ),
  ];

  static final Map<String, ThaiBank> _byCode = {for (final b in all) b.code: b};

  static ThaiBank? byCode(String? code) => code == null ? null : _byCode[code];
}
