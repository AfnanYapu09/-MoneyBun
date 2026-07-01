import '../local/database.dart';

/// Immutable snapshot of app settings (stored in the key/value Settings table).
class AppSettings {
  const AppSettings({
    this.onboardingSeen = false,
    this.authMode = 'guest',
    this.themeMode = 'system',
    this.currencyCode = 'THB',
    this.locale = 'th',
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
  final String currencyCode;
  final String locale; // 'th' | 'en'
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
      currencyCode: m[SettingsKeys.currencyCode] ?? 'THB',
      locale: m[SettingsKeys.locale] ?? 'th',
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
  static const currencyCode = 'currencyCode';
  static const locale = 'locale';
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
  Future<void> setCurrency(String code) => set(SettingsKeys.currencyCode, code);
  Future<void> setLocale(String code) => set(SettingsKeys.locale, code);
  Future<void> setSavingsGoal(int cents) =>
      setInt(SettingsKeys.savingsGoalCents, cents);
  Future<void> setLastSlipReadAt(int ms) =>
      setInt(SettingsKeys.lastSlipReadAt, ms);
  Future<void> setDisabledScanIds(Set<String> ids) =>
      set(SettingsKeys.disabledScanIds, ids.join(','));
  Future<void> setDisplayName(String v) => set(SettingsKeys.displayName, v);
  Future<void> setAvatarPath(String path) => set(SettingsKeys.avatarPath, path);
  Future<void> setUsername(String v) => set(SettingsKeys.username, v);
  Future<void> setPhone(String v) => set(SettingsKeys.phone, v);
}
