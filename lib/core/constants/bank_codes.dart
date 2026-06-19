/// Thai bank registry. Codes are the 3-digit BOT/EMVCo bank codes that appear
/// in the Slip-Verify mini-QR. `keywords` are Latin tokens the on-device OCR
/// (Latin script) may surface on a slip; `thKeywords` are distinctive Thai-name
/// fragments the on-device Thai OCR (Tesseract) may surface — both are used to
/// identify a bank from a slip's text when (or in addition to) the QR.
class ThaiBank {
  const ThaiBank({
    required this.code,
    required this.nameTh,
    required this.nameEn,
    required this.shortName,
    this.keywords = const [],
    this.thKeywords = const [],
  });

  final String code;
  final String nameTh;
  final String nameEn;
  final String shortName;
  final List<String> keywords;

  /// Distinctive Thai fragments (without the shared `ธนาคาร` prefix) so e.g.
  /// `กรุงเทพ` / `กรุงไทย` / `กรุงศรี` don't collide with each other.
  final List<String> thKeywords;
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
        keywords: ['BBL', 'BANGKOK BANK', 'BUALUANG'],
        thKeywords: ['กรุงเทพ', 'บัวหลวง']),
    ThaiBank(
        code: '004',
        nameTh: 'ธนาคารกสิกรไทย',
        nameEn: 'Kasikornbank',
        shortName: 'KBANK',
        keywords: ['KBANK', 'KASIKORN', 'K PLUS', 'KPLUS'],
        thKeywords: ['กสิกร']),
    ThaiBank(
        code: '006',
        nameTh: 'ธนาคารกรุงไทย',
        nameEn: 'Krungthai Bank',
        shortName: 'KTB',
        keywords: ['KTB', 'KRUNGTHAI', 'KRUNG THAI'],
        thKeywords: ['กรุงไทย']),
    ThaiBank(
        code: '011',
        nameTh: 'ธนาคารทหารไทยธนชาต',
        nameEn: 'TMBThanachart',
        shortName: 'TTB',
        keywords: ['TTB', 'TMB', 'THANACHART'],
        thKeywords: ['ทหารไทย', 'ธนชาต']),
    ThaiBank(
        code: '014',
        nameTh: 'ธนาคารไทยพาณิชย์',
        nameEn: 'Siam Commercial Bank',
        shortName: 'SCB',
        keywords: ['SCB', 'SIAM COMMERCIAL'],
        thKeywords: ['ไทยพาณิชย์']),
    ThaiBank(
        code: '025',
        nameTh: 'ธนาคารกรุงศรีอยุธยา',
        nameEn: 'Bank of Ayudhya',
        shortName: 'BAY',
        keywords: ['BAY', 'KRUNGSRI', 'AYUDHYA'],
        thKeywords: ['กรุงศรี', 'อยุธยา']),
    ThaiBank(
        code: '069',
        nameTh: 'ธนาคารเกียรตินาคินภัทร',
        nameEn: 'Kiatnakin Phatra',
        shortName: 'KKP',
        keywords: ['KKP', 'KIATNAKIN'],
        thKeywords: ['เกียรตินาคิน']),
    ThaiBank(
        code: '022',
        nameTh: 'ธนาคารซีไอเอ็มบีไทย',
        nameEn: 'CIMB Thai',
        shortName: 'CIMB',
        keywords: ['CIMB'],
        thKeywords: ['ซีไอเอ็มบี']),
    ThaiBank(
        code: '067',
        nameTh: 'ธนาคารทิสโก้',
        nameEn: 'TISCO Bank',
        shortName: 'TISCO',
        keywords: ['TISCO'],
        thKeywords: ['ทิสโก้']),
    ThaiBank(
        code: '024',
        nameTh: 'ธนาคารยูโอบี',
        nameEn: 'UOB Thai',
        shortName: 'UOB',
        keywords: ['UOB'],
        thKeywords: ['ยูโอบี']),
    ThaiBank(
        code: '030',
        nameTh: 'ธนาคารออมสิน',
        nameEn: 'Government Savings Bank',
        shortName: 'GSB',
        keywords: ['GSB', 'AOMSIN', 'GOVERNMENT SAVINGS'],
        thKeywords: ['ออมสิน']),
    ThaiBank(
        code: '034',
        nameTh: 'ธ.ก.ส.',
        nameEn: 'BAAC',
        shortName: 'BAAC',
        keywords: ['BAAC'],
        thKeywords: ['ธ.ก.ส', 'เกษตรและสหกรณ์']),
    ThaiBank(
        code: '035',
        nameTh: 'ธนาคารเพื่อการส่งออกฯ',
        nameEn: 'EXIM Bank',
        shortName: 'EXIM',
        keywords: ['EXIM'],
        thKeywords: ['เพื่อการส่งออก']),
    ThaiBank(
        code: '073',
        nameTh: 'ธนาคารแลนด์ แอนด์ เฮ้าส์',
        nameEn: 'Land and Houses Bank',
        shortName: 'LHB',
        keywords: ['LH BANK', 'LAND AND HOUSES'],
        thKeywords: ['แลนด์ แอนด์ เฮ้าส์', 'แลนด์']),
    ThaiBank(
        code: trueMoneyCode,
        nameTh: 'ทรูมันนี่ วอลเล็ท',
        nameEn: 'TrueMoney Wallet',
        shortName: 'TrueMoney',
        keywords: ['TRUEMONEY', 'TRUE MONEY', 'TRUEWALLET'],
        thKeywords: ['ทรูมันนี่', 'ทรูมัน']),
  ];

  static final Map<String, ThaiBank> _byCode = {
    for (final b in all) b.code: b,
  };

  static ThaiBank? byCode(String? code) => code == null ? null : _byCode[code];

  /// The first bank whose Latin or Thai keyword appears in [text] (earliest by
  /// position). Returns null when none match.
  static ThaiBank? detectFromText(String text) {
    final all = detectAllFromText(text);
    return all.isEmpty ? null : all.first;
  }

  /// Every bank mentioned in [text], ordered by where its first keyword appears
  /// (top → bottom on a slip). Scans both Latin keywords and Thai-name
  /// fragments, so it works on either the Latin or the Thai OCR pass. The
  /// positional ordering lets a caller map the first hit to the sender (top of
  /// the slip) and a later, different one to the receiver.
  static List<ThaiBank> detectAllFromText(String text) {
    final upper = text.toUpperCase();
    final earliest = <ThaiBank, int>{};
    for (final bank in all) {
      var at = -1;
      void note(int i) {
        if (i >= 0 && (at < 0 || i < at)) at = i;
      }

      for (final kw in bank.keywords) {
        note(upper.indexOf(kw.toUpperCase()));
      }
      for (final kw in bank.thKeywords) {
        note(text.indexOf(kw));
      }
      if (at >= 0) earliest[bank] = at;
    }
    final ordered = earliest.keys.toList();
    ordered.sort((a, b) => earliest[a]!.compareTo(earliest[b]!));
    return ordered;
  }
}
