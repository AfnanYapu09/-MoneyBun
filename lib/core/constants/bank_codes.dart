/// Thai bank registry. Codes are the 3-digit BOT/EMVCo bank codes that appear
/// in the Slip-Verify mini-QR. `keywords` are Latin tokens the on-device OCR
/// (Latin script) may surface on a slip, used as a fallback when no QR exists.
class ThaiBank {
  const ThaiBank({
    required this.code,
    required this.nameTh,
    required this.nameEn,
    required this.shortName,
    this.keywords = const [],
  });

  final String code;
  final String nameTh;
  final String nameEn;
  final String shortName;
  final List<String> keywords;
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
        keywords: ['BBL', 'BANGKOK BANK', 'BUALUANG']),
    ThaiBank(
        code: '004',
        nameTh: 'ธนาคารกสิกรไทย',
        nameEn: 'Kasikornbank',
        shortName: 'KBANK',
        keywords: ['KBANK', 'KASIKORN', 'K PLUS', 'KPLUS']),
    ThaiBank(
        code: '006',
        nameTh: 'ธนาคารกรุงไทย',
        nameEn: 'Krungthai Bank',
        shortName: 'KTB',
        keywords: ['KTB', 'KRUNGTHAI', 'KRUNG THAI']),
    ThaiBank(
        code: '011',
        nameTh: 'ธนาคารทหารไทยธนชาต',
        nameEn: 'TMBThanachart',
        shortName: 'TTB',
        keywords: ['TTB', 'TMB', 'THANACHART']),
    ThaiBank(
        code: '014',
        nameTh: 'ธนาคารไทยพาณิชย์',
        nameEn: 'Siam Commercial Bank',
        shortName: 'SCB',
        keywords: ['SCB', 'SIAM COMMERCIAL']),
    ThaiBank(
        code: '025',
        nameTh: 'ธนาคารกรุงศรีอยุธยา',
        nameEn: 'Bank of Ayudhya',
        shortName: 'BAY',
        keywords: ['BAY', 'KRUNGSRI', 'AYUDHYA']),
    ThaiBank(
        code: '069',
        nameTh: 'ธนาคารเกียรตินาคินภัทร',
        nameEn: 'Kiatnakin Phatra',
        shortName: 'KKP',
        keywords: ['KKP', 'KIATNAKIN']),
    ThaiBank(
        code: '022',
        nameTh: 'ธนาคารซีไอเอ็มบีไทย',
        nameEn: 'CIMB Thai',
        shortName: 'CIMB',
        keywords: ['CIMB']),
    ThaiBank(
        code: '067',
        nameTh: 'ธนาคารทิสโก้',
        nameEn: 'TISCO Bank',
        shortName: 'TISCO',
        keywords: ['TISCO']),
    ThaiBank(
        code: '024',
        nameTh: 'ธนาคารยูโอบี',
        nameEn: 'UOB Thai',
        shortName: 'UOB',
        keywords: ['UOB']),
    ThaiBank(
        code: '030',
        nameTh: 'ธนาคารออมสิน',
        nameEn: 'Government Savings Bank',
        shortName: 'GSB',
        keywords: ['GSB', 'AOMSIN', 'GOVERNMENT SAVINGS']),
    ThaiBank(
        code: '034',
        nameTh: 'ธ.ก.ส.',
        nameEn: 'BAAC',
        shortName: 'BAAC',
        keywords: ['BAAC']),
    ThaiBank(
        code: '035',
        nameTh: 'ธนาคารเพื่อการส่งออกฯ',
        nameEn: 'EXIM Bank',
        shortName: 'EXIM',
        keywords: ['EXIM']),
    ThaiBank(
        code: '073',
        nameTh: 'ธนาคารแลนด์ แอนด์ เฮ้าส์',
        nameEn: 'Land and Houses Bank',
        shortName: 'LHB',
        keywords: ['LH BANK', 'LAND AND HOUSES']),
    ThaiBank(
        code: trueMoneyCode,
        nameTh: 'ทรูมันนี่ วอลเล็ท',
        nameEn: 'TrueMoney Wallet',
        shortName: 'TrueMoney',
        keywords: ['TRUEMONEY', 'TRUE MONEY', 'TRUEWALLET']),
  ];

  static final Map<String, ThaiBank> _byCode = {
    for (final b in all) b.code: b,
  };

  static ThaiBank? byCode(String? code) => code == null ? null : _byCode[code];

  /// Find a bank by scanning OCR text for any of its Latin keywords.
  static ThaiBank? detectFromText(String text) {
    final upper = text.toUpperCase();
    for (final bank in all) {
      for (final kw in bank.keywords) {
        if (upper.contains(kw)) return bank;
      }
    }
    return null;
  }
}
