import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/database.dart';

/// Immutable snapshot of app settings (stored in the key/value Settings table).
class AppSettings {
  const AppSettings({
    this.onboardingSeen = false,
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
    this.firstSyncDone = false,
    this.homeTourSeen = false,
    this.reminderEnabled = false,
    this.reminderTime = '20:00',
    this.ultraUntil = '',
    this.signupAtMs,
    this.creditsGranted = 0,
    this.hasRedeemed = false,
    this.hasReferred = false,
  });

  final bool onboardingSeen;
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

  /// Whether this device has ever finished its first cloud pull. Gates the Home
  /// loading skeleton so it only appears on a genuinely-first login (empty local
  /// DB), never again for a returning user.
  final bool firstSyncDone;

  /// Whether the first-run Home walkthrough has been shown on this device.
  /// Device-level like [onboardingSeen] — a second account on the same phone
  /// doesn't need the tour again.
  final bool homeTourSeen;

  /// Daily "อย่าลืมจด" reminder notification. Device-level (like theme): it
  /// belongs to this phone, so it survives sign-out and never syncs.
  final bool reminderEnabled;

  /// Reminder time as 'HH:mm' (24h).
  final String reminderTime;

  /// Paid Ultra expiry as 'YYYY-MM-DD' (inclusive), or '' when never bought.
  /// Synced; granted by the developer (Firebase console) after payment.
  final String ultraUntil;

  /// Cached Firebase account creation time (epoch ms) — anchors the personal
  /// free period and the signup-month backfill. Local-only (re-derivable from
  /// auth metadata); null until the first seed.
  final int? signupAtMs;

  /// Cached referral-credit grant total, refreshed from Firestore after every
  /// completed sync. Local-only — the truth lives in the redemption docs.
  final int creditsGranted;

  /// Cached referral status: this account redeemed a code ([hasRedeemed]) /
  /// had its own code redeemed ([hasReferred]). Either one makes the account
  /// "old" — it can keep inviting but can never redeem again.
  final bool hasRedeemed;
  final bool hasReferred;

  factory AppSettings.fromMap(Map<String, String> m) {
    bool b(String k, [bool d = false]) => m[k] == null ? d : m[k] == 'true';
    int i(String k, [int d = 0]) => int.tryParse(m[k] ?? '') ?? d;
    return AppSettings(
      onboardingSeen: b(SettingsKeys.onboardingSeen),
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
      firstSyncDone: b(SettingsKeys.firstSyncDone),
      homeTourSeen: b(SettingsKeys.homeTourSeen),
      reminderEnabled: b(SettingsKeys.reminderEnabled),
      reminderTime: m[SettingsKeys.reminderTime] ?? '20:00',
      ultraUntil: m[SettingsKeys.ultraUntil] ?? '',
      signupAtMs: m[SettingsKeys.signupAtMs] == null
          ? null
          : i(SettingsKeys.signupAtMs),
      creditsGranted: i(SettingsKeys.creditsGranted),
      hasRedeemed: b(SettingsKeys.hasRedeemed),
      hasReferred: b(SettingsKeys.hasReferred),
    );
  }
}

class SettingsKeys {
  const SettingsKeys._();
  static const onboardingSeen = 'onboardingSeen';
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
  static const avatarImage = 'avatarImage';
  static const recentSearches = 'recentSearches';
  static const firstSyncDone = 'firstSyncDone';
  static const homeTourSeen = 'homeTourSeen';
  static const slipScanUpTo = 'slipScanUpTo';
  static const reminderEnabled = 'reminderEnabled';
  static const reminderTime = 'reminderTime';

  /// Retired (calendar-month Pro from the old referral scheme). Kept only so
  /// [SettingsRepository.resetUserData] keeps deleting leftover rows.
  static const proMonth = 'proMonth';
  static const ultraUntil = 'ultraUntil';
  static const signupAtMs = 'signupAtMs';
  static const creditsGranted = 'creditsGranted';
  static const hasRedeemed = 'hasRedeemed';
  static const hasReferred = 'hasReferred';

  /// Random device id used when the platform can't provide one. DEVICE-level:
  /// it backs the one-redemption-per-device lock, so it must survive
  /// sign-out/account switches (never cleared in [resetUserData]).
  static const deviceIdFallback = 'deviceIdFallback';
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
  Future<void> setFirstSyncDone(bool v) =>
      setBool(SettingsKeys.firstSyncDone, v);
  Future<void> setHomeTourSeen(bool v) => setBool(SettingsKeys.homeTourSeen, v);
  Future<void> setReminderEnabled(bool v) =>
      setBool(SettingsKeys.reminderEnabled, v);
  Future<void> setReminderTime(String hhmm) =>
      set(SettingsKeys.reminderTime, hhmm);
  Future<void> setSignupAtMs(int ms) => setInt(SettingsKeys.signupAtMs, ms);
  Future<void> setCreditsGranted(int credits) =>
      setInt(SettingsKeys.creditsGranted, credits);
  Future<void> setHasRedeemed(bool v) => setBool(SettingsKeys.hasRedeemed, v);
  Future<void> setHasReferred(bool v) => setBool(SettingsKeys.hasReferred, v);

  /// The stable device id fallback (created on first use). Device-level —
  /// survives sign-out — because it backs the per-device redemption lock.
  Future<String?> getDeviceIdFallback() =>
      _db.getSetting(SettingsKeys.deviceIdFallback);
  Future<void> setDeviceIdFallback(String id) =>
      set(SettingsKeys.deviceIdFallback, id);

  /// Photo time (epoch ms) the slip scanner has read up to on this device, or
  /// null when never recorded. An extra guard against re-reading photos it has
  /// already looked at; cleared on sign-out like the other per-account values.
  Future<int?> getSlipScanUpTo() async {
    final raw = await _db.getSetting(SettingsKeys.slipScanUpTo);
    return int.tryParse(raw ?? '');
  }

  Future<void> setSlipScanUpTo(int ms) => setInt(SettingsKeys.slipScanUpTo, ms);

  /// Clear the signed-in user's local settings on sign-out. Device preferences
  /// (theme, language, currency, onboarding-seen) are intentionally kept; only
  /// account-specific values and the first-sync flag are removed so the next
  /// account starts clean and re-pulls from its own cloud.
  Future<void> resetUserData() async {
    const userKeys = [
      SettingsKeys.firstSyncDone,
      SettingsKeys.displayName,
      SettingsKeys.username,
      SettingsKeys.phone,
      SettingsKeys.avatarPath,
      SettingsKeys.avatarImage,
      SettingsKeys.savingsGoalCents,
      SettingsKeys.lastSlipReadAt,
      SettingsKeys.disabledScanIds,
      SettingsKeys.recentSearches,
      SettingsKeys.slipScanUpTo,
      SettingsKeys.proMonth,
      SettingsKeys.ultraUntil,
      SettingsKeys.signupAtMs,
      SettingsKeys.creditsGranted,
      SettingsKeys.hasRedeemed,
      SettingsKeys.hasReferred,
      // SettingsKeys.deviceIdFallback is deliberately NOT here: the
      // one-redemption-per-device lock must survive account switches —
      // wiping it on sign-out would let a second account redeem again.
    ];
    for (final key in userKeys) {
      await _db.deleteSetting(key);
    }
  }

  /// Save a newly picked profile photo: copy it into the documents dir as
  /// `avatar_<uid>_<updatedAt>` (the uid lets [restoreAvatarPath] re-find it
  /// after a sign-out; the updatedAt matches the synced `avatarImage` row so
  /// [syncAvatarFromCloud] recognises the file as current), point avatarPath
  /// at it, and store the bytes base64 in the synced `avatarImage` setting so
  /// every other device (and a reinstall) gets the photo from the cloud.
  Future<void> saveAvatarPhoto({
    required String uid,
    required String sourcePath,
  }) async {
    final old = (await read()).avatarPath;
    final bytes = await File(sourcePath).readAsBytes();
    // A Firestore doc caps at 1 MiB; the picker's 800px/q85 output is far
    // smaller, but guard anyway — an oversized photo stays local-only.
    final synced = bytes.length <= 700 * 1024;
    int updatedAt;
    if (synced) {
      await set(SettingsKeys.avatarImage, base64Encode(bytes));
      updatedAt = await _settingUpdatedAt(SettingsKeys.avatarImage) ??
          DateTime.now().millisecondsSinceEpoch;
    } else {
      // Never reuse the previous (stale) avatarImage timestamp here: since we
      // didn't push to the cloud, that would name this file identically to
      // whatever smaller photo IS synced, silently overwriting its bytes and
      // making syncAvatarFromCloud believe it's already up to date forever.
      // A fresh timestamp keeps this local-only photo on its own filename.
      updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
    final dir = await getApplicationDocumentsDirectory();
    // Always .jpg so [syncAvatarFromCloud] recognises the file as current
    // regardless of the picked file's extension (Flutter decodes by content).
    final dest = p.join(dir.path, 'avatar_${uid}_$updatedAt.jpg');
    await File(sourcePath).copy(dest);
    await setAvatarPath(dest);
    // Best-effort cleanup of the previous photo.
    if (old != null && old.isNotEmpty && old != dest) {
      try {
        File(old).deleteSync();
      } catch (_) {}
    }
  }

  /// Re-point avatarPath at the signed-in account's photo after a login on
  /// this device. Sign-out only wipes the avatarPath *setting*, not the
  /// `avatar_<uid>_<ms>` file — so the same account logging back in gets its
  /// photo back instantly, before the cloud pull even starts.
  Future<void> restoreAvatarPath(String uid) async {
    try {
      final current = (await read()).avatarPath;
      if (current != null && current.isNotEmpty && File(current).existsSync()) {
        return; // already pointing at a real photo — don't override
      }
      final dir = await getApplicationDocumentsDirectory();
      final prefix = 'avatar_${uid}_';
      final photos = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(prefix))
          .toList()
        // Filenames embed epoch ms, so a name sort is a time sort.
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      if (photos.isEmpty) return;
      await setAvatarPath(photos.last.path);
    } catch (_) {
      // Best-effort: a failed restore just leaves the mascot fallback.
    }
  }

  /// Materialise the cloud profile photo after a sync: if the synced
  /// `avatarImage` row is newer than what avatarPath points at, decode it to
  /// `avatar_<uid>_<updatedAt>` and re-point. Runs after every successful full
  /// sync, which covers a new device's first login, a reinstall, and a photo
  /// changed on another device. No-ops when the pointer already matches the
  /// row's updatedAt (the common case, including right after a local pick).
  Future<void> syncAvatarFromCloud(String uid) async {
    try {
      final rows = await _db.getAllSettings();
      final img = rows.where((r) => r.key == SettingsKeys.avatarImage).toList();
      if (img.isEmpty || img.first.value.isEmpty) return;
      final updatedAt = img.first.updatedAt;
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, 'avatar_${uid}_$updatedAt.jpg');
      final current = (await read()).avatarPath;
      if (current == dest && File(dest).existsSync()) return; // up to date
      if (!File(dest).existsSync()) {
        await File(dest).writeAsBytes(base64Decode(img.first.value));
      }
      await setAvatarPath(dest);
      if (current != null && current.isNotEmpty && current != dest) {
        try {
          File(current).deleteSync();
        } catch (_) {}
      }
    } catch (_) {
      // Best-effort: a corrupt/missing cloud image just leaves the mascot.
    }
  }

  Future<int?> _settingUpdatedAt(String key) async {
    final rows = await _db.getAllSettings();
    for (final r in rows) {
      if (r.key == key) return r.updatedAt;
    }
    return null;
  }

  /// Recently submitted search terms (most-recent first), persisted so the
  /// Search screen's history survives leaving the screen. Stored newline-joined.
  Future<List<String>> getRecentSearches() async {
    final raw = await _db.getSetting(SettingsKeys.recentSearches);
    if (raw == null || raw.isEmpty) return [];
    return raw.split('\n').where((s) => s.isNotEmpty).toList();
  }

  Future<void> setRecentSearches(List<String> items) =>
      set(SettingsKeys.recentSearches, items.join('\n'));
}
