import 'local/database.dart';
import 'repositories/settings_repository.dart';

/// Monotonic counter bumped on every auth-state change and every local-data
/// wipe. Long-lived async campaigns (a sync run, post-sync callbacks, a
/// credits refresh) capture the value when they start and abort their
/// remaining WRITES once it has moved on — the session they were working for
/// no longer exists, and a late write would plant the previous account's data
/// into a freshly wiped database (or resurrect a deleted watermark).
class SessionGeneration {
  int _value = 0;

  int get value => _value;

  void bump() => _value++;

  bool isCurrent(int captured) => captured == _value;
}

/// Ensures the local database belongs to the signed-in account.
///
/// The sign-out wipe lives in the Settings screen's logout flow — but not
/// every sign-out passes through it: Firebase can revoke the session itself
/// (password changed elsewhere, token revoked, account disabled), and the app
/// can die between `signOut()` and the wipe. In all of those the previous
/// account's full database stays on disk, the next account would see it, and
/// its still-pending rows would be pushed into the NEXT account's cloud.
///
/// [ensure] runs before every full sync: it compares the persisted owner uid
/// with the current one and wipes (+ re-seeds defaults) on a mismatch. The
/// same account signing back in keeps its data — including un-pushed rows,
/// which then upload to their rightful cloud.
class DbOwnershipGuard {
  DbOwnershipGuard(this._db, this._settings, this._gen);

  final AppDatabase _db;
  final SettingsRepository _settings;
  final SessionGeneration _gen;

  Future<void> ensure(String uid) async {
    final owner = await _settings.dbOwnerUid();
    if (owner == uid) return;
    if (owner != null && owner.isNotEmpty) {
      // Abort in-flight work for the old session before its writes can land
      // in the wiped database.
      _gen.bump();
      await _db.clearAllData();
      await _settings.resetUserData();
      // Never leave the account bare: seeds are updatedAt-0 rows that lose
      // last-write-wins to the account's real cloud data on the next pull.
      await _db.seedDefaults();
    }
    await _settings.setDbOwnerUid(uid);
  }
}
