// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'MoneyBun';

  @override
  String get tagline => 'น้องบันช่วยจดเงินให้';

  @override
  String get navHome => 'หน้าหลัก';

  @override
  String get navStats => 'สถิติ';

  @override
  String get navAdd => 'เพิ่ม';

  @override
  String get navAccounts => 'บัญชี';

  @override
  String get navSettings => 'ตั้งค่า';

  @override
  String get income => 'รายรับ';

  @override
  String get expense => 'รายจ่าย';

  @override
  String get transfer => 'ย้ายเงิน';

  @override
  String get balance => 'ยอดคงเหลือ';

  @override
  String get total => 'รวม';

  @override
  String get today => 'วันนี้';

  @override
  String get addTransaction => 'เพิ่มรายการ';

  @override
  String get editTransaction => 'แก้ไขรายการ';

  @override
  String get amount => 'จำนวนเงิน';

  @override
  String get category => 'หมวดหมู่';

  @override
  String get selectCategory => 'เลือกหมวดหมู่';

  @override
  String get account => 'บัญชี';

  @override
  String get fromAccount => 'จากบัญชี';

  @override
  String get toAccount => 'ไปบัญชี';

  @override
  String get note => 'บันทึกช่วยจำ';

  @override
  String get noteHint => 'รายละเอียด (ไม่บังคับ)';

  @override
  String get dateTime => 'วันและเวลา';

  @override
  String get save => 'บันทึก';

  @override
  String get delete => 'ลบ';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get edit => 'แก้ไข';

  @override
  String get confirmDelete => 'ต้องการลบรายการนี้ใช่ไหม?';

  @override
  String get scanSlip => 'สแกนสลิป';

  @override
  String get pickFromGallery => 'เลือกจากแกลเลอรี';

  @override
  String get takePhoto => 'ถ่ายรูป';

  @override
  String get scanning => 'กำลังอ่านสลิป...';

  @override
  String get slipDetected => 'อ่านสลิปสำเร็จ';

  @override
  String get slipNotDetected => 'อ่านสลิปไม่สำเร็จ ลองใหม่หรือกรอกเอง';

  @override
  String get verifyOnline => 'ตรวจสอบออนไลน์';

  @override
  String get lowConfidence => 'ความมั่นใจต่ำ โปรดตรวจสอบข้อมูล';

  @override
  String get useAnyway => 'ใช้ข้อมูลนี้';

  @override
  String get accounts => 'บัญชี';

  @override
  String get addAccount => 'เพิ่มบัญชี';

  @override
  String get editAccount => 'แก้ไขบัญชี';

  @override
  String get accountName => 'ชื่อบัญชี';

  @override
  String get accountType => 'ประเภทบัญชี';

  @override
  String get acctCash => 'เงินสด';

  @override
  String get acctBank => 'ธนาคาร';

  @override
  String get acctEwallet => 'วอลเล็ต';

  @override
  String get acctSavings => 'เงินออม';

  @override
  String get acctCredit => 'บัตรเครดิต';

  @override
  String get openingBalance => 'ยอดตั้งต้น';

  @override
  String get quickTransfer => 'ย้ายเงินด่วน';

  @override
  String get stats => 'สถิติ';

  @override
  String get monthlySummary => 'สรุปรายเดือน';

  @override
  String get byCategory => 'แยกตามหมวดหมู่';

  @override
  String get noData => 'ยังไม่มีข้อมูล';

  @override
  String get settings => 'ตั้งค่า';

  @override
  String get language => 'ภาษา';

  @override
  String get langThai => 'ไทย';

  @override
  String get langEnglish => 'English';

  @override
  String get signInGoogle => 'เข้าสู่ระบบด้วย Google';

  @override
  String get signOut => 'ออกจากระบบ';

  @override
  String get syncStatus => 'สถานะซิงค์';

  @override
  String get syncNow => 'ซิงค์ตอนนี้';

  @override
  String syncedAt(String time) {
    return 'ซิงค์ล่าสุด $time';
  }

  @override
  String get notSignedIn => 'ยังไม่ได้เข้าสู่ระบบ';

  @override
  String get manageCategories => 'จัดการหมวดหมู่';

  @override
  String get slipApiToggle => 'ใช้ API ตรวจสลิปออนไลน์';

  @override
  String get slipApiDesc =>
      'ตรวจสลิปแม่นยำขึ้น (ต้องต่อเน็ต และตั้งค่าเซิร์ฟเวอร์)';

  @override
  String get about => 'เกี่ยวกับ';

  @override
  String get aboutBun => 'MoneyBun • น้องบันตัวสีส้มพิกเซล 🐰';

  @override
  String get emptyDayTitle => 'ยังไม่มีรายการวันนี้';

  @override
  String get emptyDaySubtitle => 'แตะปุ่ม + เพื่อเพิ่มรายการแรก';

  @override
  String get month => 'เดือน';

  @override
  String get requiredField => 'กรุณากรอกข้อมูล';

  @override
  String get invalidAmount => 'จำนวนเงินไม่ถูกต้อง';
}
