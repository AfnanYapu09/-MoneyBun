/// A Thai bank / e-wallet whose gallery album the slip scanner can read. This
/// drives the "which banks to scan" sheet and, via [albumKeywords], lets the
/// importer attribute an album to a bank so it can be turned off.
///
/// [id] is a short symbol (matches the bundled logo `assets/banks/<id>.png` and
/// the open-source logo set). [brandHex] is an ARGB hex used as the fallback
/// badge colour when no logo image is present. Bank codes/colours/logo sources
/// are from the project's `thai_banks_reference.json`.
class ScanBank {
  const ScanBank({
    required this.id,
    required this.nameTh,
    required this.shortName,
    required this.brandHex,
    required this.albumKeywords,
  });

  final String id;
  final String nameTh;
  final String shortName;
  final String brandHex;
  final List<String> albumKeywords;
}

class BankCatalog {
  const BankCatalog._();

  /// The banks/wallets shown in the scan-selection sheet, in display order.
  static const all = <ScanBank>[
    ScanBank(
      id: 'make',
      nameTh: 'Make by KBank',
      shortName: 'MAKE',
      brandHex: 'FF14B8A6',
      albumKeywords: ['make by kbank'],
    ),
    ScanBank(
      id: 'kbank',
      nameTh: 'กสิกรไทย',
      shortName: 'KBANK',
      brandHex: 'FF138F2D',
      albumKeywords: ['k plus', 'kplus', 'kasikorn', 'กสิกร', 'kbank'],
    ),
    ScanBank(
      id: 'truemoney',
      nameTh: 'ทรูมันนี่',
      shortName: 'TRUE',
      brandHex: 'FFF47B20',
      albumKeywords: ['truemoney', 'true money', 'ทรูมันนี่', 'ทรูมัน'],
    ),
    ScanBank(
      id: 'ktb',
      nameTh: 'กรุงไทย',
      shortName: 'KTB',
      brandHex: 'FF1BA5E1',
      albumKeywords: ['krungthai', 'กรุงไทย'],
    ),
    ScanBank(
      id: 'scb',
      nameTh: 'ไทยพาณิชย์',
      shortName: 'SCB',
      brandHex: 'FF4E2E7F',
      albumKeywords: ['scb', 'ไทยพาณิชย์'],
    ),
    ScanBank(
      id: 'ttb',
      nameTh: 'ทหารไทยธนชาต',
      shortName: 'TTB',
      brandHex: 'FF1279BE',
      albumKeywords: ['ttb', 'tmb'],
    ),
    ScanBank(
      id: 'gsb',
      nameTh: 'ออมสิน',
      shortName: 'GSB',
      brandHex: 'FFEB198D',
      albumKeywords: ['gsb', 'mymo', 'ออมสิน'],
    ),
    ScanBank(
      id: 'bay',
      nameTh: 'กรุงศรีอยุธยา',
      shortName: 'BAY',
      brandHex: 'FFFEC43B',
      albumKeywords: ['kma', 'krungsri', 'กรุงศรี', 'uchoose'],
    ),
    ScanBank(
      id: 'cimb',
      nameTh: 'ซีไอเอ็มบีไทย',
      shortName: 'CIMB',
      brandHex: 'FF7E2F36',
      albumKeywords: ['cimb'],
    ),
    ScanBank(
      id: 'kkp',
      nameTh: 'เกียรตินาคินภัทร',
      shortName: 'KKP',
      brandHex: 'FF199CC5',
      albumKeywords: ['kkp', 'kiatnakin'],
    ),
    ScanBank(
      id: 'uob',
      nameTh: 'ยูโอบี',
      shortName: 'UOB',
      brandHex: 'FF0B3979',
      albumKeywords: ['uob', 'tmrw'],
    ),
    ScanBank(
      id: 'ghb',
      nameTh: 'อาคารสงเคราะห์ (ธอส.)',
      shortName: 'GHB',
      brandHex: 'FFF57D23',
      albumKeywords: ['ghb', 'อาคารสงเคราะห์', 'ธอส'],
    ),
    ScanBank(
      id: 'baac',
      nameTh: 'ธ.ก.ส.',
      shortName: 'BAAC',
      brandHex: 'FF4B9B1D',
      albumKeywords: ['baac', 'ธกส'],
    ),
    ScanBank(
      id: 'lhb',
      nameTh: 'แลนด์ แอนด์ เฮ้าส์',
      shortName: 'LHB',
      brandHex: 'FFF68B1F',
      albumKeywords: ['lh bank', 'lhbank'],
    ),
    ScanBank(
      id: 'paotang',
      nameTh: 'เป๋าตัง',
      shortName: 'เป๋า',
      brandHex: 'FF1B4D9B',
      albumKeywords: ['paotang', 'pao tang', 'เป๋าตัง'],
    ),
  ];
}
