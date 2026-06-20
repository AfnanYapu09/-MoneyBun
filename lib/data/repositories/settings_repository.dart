import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../local/database.dart';

/// Immutable snapshot of app settings (stored in the key/value Settings table).
class AppSettings {
  const AppSettings({
    this.onboardingSeen = false,
    this.authMode = 'guest',
    this.themeMode = 'system',
    this.accentColor = 'FFC4694A',
    this.currencyCode = 'THB',
    this.locale = 'th',
    this.hideBalance = false,
    this.pinEnabled = false,
    this.pinHash,
    this.biometricEnabled = false,
    this.savingsGoalCents = 0,
    this.lastSlipReadAt,
    this.disabledScanIds = const {},
    this.displayName = 'คุณบัน',
    this.username = 'moneybun',
    this.phone = '',
    this.avatarPath,
  });

  final bool onboardingSeen;
  final String authMode; // 'guest' | 'signedIn'
  final String themeMode; // 'light' | 'dark' | 'system'
  final String accentColor; // ARGB hex
  final String currencyCode;
  final String locale; // 'th' | 'en'
  final bool hideBalance;
  final bool pinEnabled;
  final String? pinHash;
  final bool biometricEnabled;
  final int savingsGoalCents;
  final int? lastSlipReadAt;

  /// Scan-catalog ids the user turned off (their slip albums aren't scanned).
  final Set<String> disabledScanIds;
  final String displayName;
  final String username;
  final String phone;

  /// Absolute path to the user's chosen profile photo (null = use the mascot).
  final String? avatarPath;

  factory AppSettings.fromMap(Map<String, String> m) {
    bool b(String k, [bool d = false]) => m[k] == null ? d : m[k] == 'true';
    int i(String k, [int d = 0]) => int.tryParse(m[k] ?? '') ?? d;
    return AppSettings(
      onboardingSeen: b(SettingsKeys.onboardingSeen),
      authMode: m[SettingsKeys.authMode] ?? 'guest',
      themeMode: m[SettingsKeys.themeMode] ?? 'system',
      accentColor: m[SettingsKeys.accentColor] ?? 'FFC4694A',
      currencyCode: m[SettingsKeys.currencyCode] ?? 'THB',
      locale: m[SettingsKeys.locale] ?? 'th',
      hideBalance: b(SettingsKeys.hideBalance),
      pinEnabled: b(SettingsKeys.pinEnabled),
      pinHash: m[SettingsKeys.pinHash],
      biometricEnabled: b(SettingsKeys.biometricEnabled),
      savingsGoalCents: i(SettingsKeys.savingsGoalCents),
      lastSlipReadAt: m[SettingsKeys.lastSlipReadAt] == null
          ? null
          : i(SettingsKeys.lastSlipReadAt),
      disabledScanIds: (m[SettingsKeys.disabledScanIds] ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toSet(),
      displayName: m[SettingsKeys.displayName] ?? 'คุณบัน',
      username: m[SettingsKeys.username] ?? 'moneybun',
      phone: m[SettingsKeys.phone] ?? '',
      avatarPath: m[SettingsKeys.avatarPath],
    );
  }
}

class SettingsKeys {
  const SettingsKeys._();
  static const onboardingSeen = 'onboardingSeen';
  static const authMode = 'authMode';
  static const themeMode = 'themeMode';
  static const accentColor = 'accentColor';
  static const currencyCode = 'currencyCode';
  static const locale = 'locale';
  static const hideBalance = 'hideBalance';
  static const pinEnabled = 'pinEnabled';
  static const pinHash = 'pinHash';
  static const biometricEnabled = 'biometricEnabled';
  static const savingsGoalCents = 'savingsGoalCents';
  static const lastSlipReadAt = 'lastSlipReadAt';
  static const disabledScanIds = 'disabledScanIds';
  static const displayName = 'displayName';
  static const username = 'username';
  static const phone = 'phone';
  static const avatarPath = 'avatarPath';
}

/// Reads/writes app settings. Backed by the Drift key/value Settings table so
/// there is a single local source of truth (no shared_preferences).
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// Salt for the PIN hash. Not a security boundary (local-only convenience
  /// lock), just avoids storing the PIN in plain text.
  static const _pinSalt = 'moneybun.pin.v1';

  Stream<AppSettings> watch() => _db.watchSettings().map(_toSettings);

  Future<AppSettings> read() async {
    final rows = await _db.watchSettings().first;
    return _toSettings(rows);
  }

  AppSettings _toSettings(List<SettingRow> rows) =>
      AppSettings.fromMap({for (final r in rows) r.key: r.value});

  Future<void> set(String key, String value) => _db.setSetting(key, value);
  Future<void> setBool(String key, bool value) =>
      _db.setSetting(key, value.toString());
  Future<void> setInt(String key, int value) =>
      _db.setSetting(key, value.toString());

  // Convenience setters used across the UI.
  Future<void> setOnboardingSeen(bool v) =>
      setBool(SettingsKeys.onboardingSeen, v);
  Future<void> setAuthMode(String v) => set(SettingsKeys.authMode, v);
  Future<void> setThemeMode(String v) => set(SettingsKeys.themeMode, v);
  Future<void> setAccentColor(String hex) => set(SettingsKeys.accentColor, hex);
  Future<void> setCurrency(String code) => set(SettingsKeys.currencyCode, code);
  Future<void> setLocale(String code) => set(SettingsKeys.locale, code);
  Future<void> setHideBalance(bool v) => setBool(SettingsKeys.hideBalance, v);
  Future<void> setBiometricEnabled(bool v) =>
      setBool(SettingsKeys.biometricEnabled, v);
  Future<void> setSavingsGoal(int cents) =>
      setInt(SettingsKeys.savingsGoalCents, cents);
  Future<void> setLastSlipReadAt(int ms) =>
      setInt(SettingsKeys.lastSlipReadAt, ms);
  Future<void> setDisabledScanIds(Set<String> ids) =>
      set(SettingsKeys.disabledScanIds, ids.join(','));
  Future<void> setDisplayName(String v) => set(SettingsKeys.displayName, v);
  Future<void> setAvatarPath(String path) =>
      set(SettingsKeys.avatarPath, path);
  Future<void> setUsername(String v) => set(SettingsKeys.username, v);
  Future<void> setPhone(String v) => set(SettingsKeys.phone, v);

  // ---- PIN ----
  String _hash(String pin) =>
      sha256.convert(utf8.encode('$_pinSalt:$pin')).toString();

  Future<void> setPin(String pin) async {
    await set(SettingsKeys.pinHash, _hash(pin));
    await setBool(SettingsKeys.pinEnabled, true);
  }

  Future<void> clearPin() async {
    await set(SettingsKeys.pinHash, '');
    await setBool(SettingsKeys.pinEnabled, false);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _db.getSetting(SettingsKeys.pinHash);
    return stored != null && stored.isNotEmpty && stored == _hash(pin);
  }
}
