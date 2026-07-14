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

  /// In-flight call, if any. `ensure` has no other reentrancy protection, and
  /// two callers overlapping (e.g. SyncController's launch-time constructor
  /// microtask racing its auth-state replay) could otherwise both read the
  /// same stale owner before either writes the new one — running the wipe
  /// sequence (including its own [SessionGeneration.bump]) twice, the second
  /// of which would abort the first caller's still-in-flight sync mid-write.
  Future<void>? _inFlight;

  Future<void> ensure(String uid) {
    final existing = _inFlight;
    // Queue behind the in-flight call instead of racing it, then re-check:
    // the situation (and even the target uid) may have changed by the time
    // it finishes.
    if (existing != null) return existing.then((_) => ensure(uid));
    final future = _ensure(uid);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _ensure(String uid) async {
    final owner = await _settings.dbOwnerUid();
    if (owner == uid) return;
    if (owner != null && owner.isNotEmpty) {
      // Abort in-flight work for the old session before its writes can land
      // in the wiped database.
      _gen.bump();
      // Drop the previous account's "this device has synced" flag FIRST: the
      // boot flow's bypasses read it, and during the wipe below the flag
      // would still say true while the tables are mid-teardown. (Crash-safe:
      // flag gone + owner intact just means the next launch re-wipes.)
      await _settings.setFirstSyncDone(false);
      await _db.clearAllData();
      await _settings.resetUserData();
      // Never leave the account bare: seeds are updatedAt-0 rows that lose
      // last-write-wins to the account's real cloud data on the next pull.
      await _db.seedDefaults();
    }
    await _settings.setDbOwnerUid(uid);
  }
}
