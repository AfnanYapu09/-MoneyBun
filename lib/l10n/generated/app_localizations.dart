import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('th')];

  /// No description provided for @appTitle.
  ///
  /// In th, this message translates to:
  /// **'MoneyBun'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In th, this message translates to:
  /// **'น้องบันช่วยจดเงินให้'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In th, this message translates to:
  /// **'หน้าหลัก'**
  String get navHome;

  /// No description provided for @navStats.
  ///
  /// In th, this message translates to:
  /// **'สถิติ'**
  String get navStats;

  /// No description provided for @navAdd.
  ///
  /// In th, this message translates to:
  /// **'เพิ่ม'**
  String get navAdd;

  /// No description provided for @navAccounts.
  ///
  /// In th, this message translates to:
  /// **'บัญชี'**
  String get navAccounts;

  /// No description provided for @navSettings.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่า'**
  String get navSettings;

  /// No description provided for @income.
  ///
  /// In th, this message translates to:
  /// **'รายรับ'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In th, this message translates to:
  /// **'รายจ่าย'**
  String get expense;

  /// No description provided for @transfer.
  ///
  /// In th, this message translates to:
  /// **'ย้ายเงิน'**
  String get transfer;

  /// No description provided for @balance.
  ///
  /// In th, this message translates to:
  /// **'ยอดคงเหลือ'**
  String get balance;

  /// No description provided for @total.
  ///
  /// In th, this message translates to:
  /// **'รวม'**
  String get total;

  /// No description provided for @today.
  ///
  /// In th, this message translates to:
  /// **'วันนี้'**
  String get today;

  /// No description provided for @addTransaction.
  ///
  /// In th, this message translates to:
  /// **'เพิ่มรายการ'**
  String get addTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In th, this message translates to:
  /// **'แก้ไขรายการ'**
  String get editTransaction;

  /// No description provided for @amount.
  ///
  /// In th, this message translates to:
  /// **'จำนวนเงิน'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In th, this message translates to:
  /// **'หมวดหมู่'**
  String get category;

  /// No description provided for @selectCategory.
  ///
  /// In th, this message translates to:
  /// **'เลือกหมวดหมู่'**
  String get selectCategory;

  /// No description provided for @account.
  ///
  /// In th, this message translates to:
  /// **'บัญชี'**
  String get account;

  /// No description provided for @fromAccount.
  ///
  /// In th, this message translates to:
  /// **'จากบัญชี'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In th, this message translates to:
  /// **'ไปบัญชี'**
  String get toAccount;

  /// No description provided for @note.
  ///
  /// In th, this message translates to:
  /// **'บันทึกช่วยจำ'**
  String get note;

  /// No description provided for @noteHint.
  ///
  /// In th, this message translates to:
  /// **'รายละเอียด (ไม่บังคับ)'**
  String get noteHint;

  /// No description provided for @dateTime.
  ///
  /// In th, this message translates to:
  /// **'วันและเวลา'**
  String get dateTime;

  /// No description provided for @save.
  ///
  /// In th, this message translates to:
  /// **'บันทึก'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In th, this message translates to:
  /// **'ลบ'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get cancel;

  /// No description provided for @edit.
  ///
  /// In th, this message translates to:
  /// **'แก้ไข'**
  String get edit;

  /// No description provided for @confirmDelete.
  ///
  /// In th, this message translates to:
  /// **'ต้องการลบรายการนี้ใช่ไหม?'**
  String get confirmDelete;

  /// No description provided for @scanSlip.
  ///
  /// In th, this message translates to:
  /// **'สแกนสลิป'**
  String get scanSlip;

  /// No description provided for @pickFromGallery.
  ///
  /// In th, this message translates to:
  /// **'เลือกจากแกลเลอรี'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In th, this message translates to:
  /// **'ถ่ายรูป'**
  String get takePhoto;

  /// No description provided for @scanning.
  ///
  /// In th, this message translates to:
  /// **'กำลังอ่านสลิป...'**
  String get scanning;

  /// No description provided for @slipDetected.
  ///
  /// In th, this message translates to:
  /// **'อ่านสลิปสำเร็จ'**
  String get slipDetected;

  /// No description provided for @slipNotDetected.
  ///
  /// In th, this message translates to:
  /// **'อ่านสลิปไม่สำเร็จ ลองใหม่หรือกรอกเอง'**
  String get slipNotDetected;

  /// No description provided for @verifyOnline.
  ///
  /// In th, this message translates to:
  /// **'ตรวจสอบออนไลน์'**
  String get verifyOnline;

  /// No description provided for @lowConfidence.
  ///
  /// In th, this message translates to:
  /// **'ความมั่นใจต่ำ โปรดตรวจสอบข้อมูล'**
  String get lowConfidence;

  /// No description provided for @useAnyway.
  ///
  /// In th, this message translates to:
  /// **'ใช้ข้อมูลนี้'**
  String get useAnyway;

  /// No description provided for @accounts.
  ///
  /// In th, this message translates to:
  /// **'บัญชี'**
  String get accounts;

  /// No description provided for @addAccount.
  ///
  /// In th, this message translates to:
  /// **'เพิ่มบัญชี'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In th, this message translates to:
  /// **'แก้ไขบัญชี'**
  String get editAccount;

  /// No description provided for @accountName.
  ///
  /// In th, this message translates to:
  /// **'ชื่อบัญชี'**
  String get accountName;

  /// No description provided for @accountType.
  ///
  /// In th, this message translates to:
  /// **'ประเภทบัญชี'**
  String get accountType;

  /// No description provided for @acctCash.
  ///
  /// In th, this message translates to:
  /// **'เงินสด'**
  String get acctCash;

  /// No description provided for @acctBank.
  ///
  /// In th, this message translates to:
  /// **'ธนาคาร'**
  String get acctBank;

  /// No description provided for @acctEwallet.
  ///
  /// In th, this message translates to:
  /// **'วอลเล็ต'**
  String get acctEwallet;

  /// No description provided for @acctSavings.
  ///
  /// In th, this message translates to:
  /// **'เงินออม'**
  String get acctSavings;

  /// No description provided for @acctCredit.
  ///
  /// In th, this message translates to:
  /// **'บัตรเครดิต'**
  String get acctCredit;

  /// No description provided for @openingBalance.
  ///
  /// In th, this message translates to:
  /// **'ยอดตั้งต้น'**
  String get openingBalance;

  /// No description provided for @quickTransfer.
  ///
  /// In th, this message translates to:
  /// **'ย้ายเงินด่วน'**
  String get quickTransfer;

  /// No description provided for @stats.
  ///
  /// In th, this message translates to:
  /// **'สถิติ'**
  String get stats;

  /// No description provided for @monthlySummary.
  ///
  /// In th, this message translates to:
  /// **'สรุปรายเดือน'**
  String get monthlySummary;

  /// No description provided for @byCategory.
  ///
  /// In th, this message translates to:
  /// **'แยกตามหมวดหมู่'**
  String get byCategory;

  /// No description provided for @noData.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีข้อมูล'**
  String get noData;

  /// No description provided for @settings.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่า'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In th, this message translates to:
  /// **'ภาษา'**
  String get language;

  /// No description provided for @langThai.
  ///
  /// In th, this message translates to:
  /// **'ไทย'**
  String get langThai;

  /// No description provided for @langEnglish.
  ///
  /// In th, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @signInGoogle.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบด้วย Google'**
  String get signInGoogle;

  /// No description provided for @signOut.
  ///
  /// In th, this message translates to:
  /// **'ออกจากระบบ'**
  String get signOut;

  /// No description provided for @syncStatus.
  ///
  /// In th, this message translates to:
  /// **'สถานะซิงค์'**
  String get syncStatus;

  /// No description provided for @syncNow.
  ///
  /// In th, this message translates to:
  /// **'ซิงค์ตอนนี้'**
  String get syncNow;

  /// No description provided for @syncedAt.
  ///
  /// In th, this message translates to:
  /// **'ซิงค์ล่าสุด {time}'**
  String syncedAt(String time);

  /// No description provided for @notSignedIn.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่ได้เข้าสู่ระบบ'**
  String get notSignedIn;

  /// No description provided for @manageCategories.
  ///
  /// In th, this message translates to:
  /// **'จัดการหมวดหมู่'**
  String get manageCategories;

  /// No description provided for @slipApiToggle.
  ///
  /// In th, this message translates to:
  /// **'ใช้ API ตรวจสลิปออนไลน์'**
  String get slipApiToggle;

  /// No description provided for @slipApiDesc.
  ///
  /// In th, this message translates to:
  /// **'ตรวจสลิปแม่นยำขึ้น (ต้องต่อเน็ต และตั้งค่าเซิร์ฟเวอร์)'**
  String get slipApiDesc;

  /// No description provided for @about.
  ///
  /// In th, this message translates to:
  /// **'เกี่ยวกับ'**
  String get about;

  /// No description provided for @aboutBun.
  ///
  /// In th, this message translates to:
  /// **'MoneyBun • น้องบันตัวสีส้มพิกเซล 🐰'**
  String get aboutBun;

  /// No description provided for @emptyDayTitle.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีรายการวันนี้'**
  String get emptyDayTitle;

  /// No description provided for @emptyDaySubtitle.
  ///
  /// In th, this message translates to:
  /// **'แตะปุ่ม + เพื่อเพิ่มรายการแรก'**
  String get emptyDaySubtitle;

  /// No description provided for @month.
  ///
  /// In th, this message translates to:
  /// **'เดือน'**
  String get month;

  /// No description provided for @requiredField.
  ///
  /// In th, this message translates to:
  /// **'กรุณากรอกข้อมูล'**
  String get requiredField;

  /// No description provided for @invalidAmount.
  ///
  /// In th, this message translates to:
  /// **'จำนวนเงินไม่ถูกต้อง'**
  String get invalidAmount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
