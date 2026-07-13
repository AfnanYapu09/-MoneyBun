import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'sync_engine.dart';

/// Drives automatic sync so the user never has to tap "Sync now":
/// - a full sync (pull + push) when the user signs in, when this controller
///   starts while already signed in, and whenever the app returns to the
///   foreground;
/// - a cheap push-only sync (no Firestore reads) shortly after any local data
///   change, debounced so a burst of edits uploads once. The change signal is
///   wired up by [syncControllerProvider] via `ref.listen`.
///
/// Kept alive for the app's lifetime by watching `syncControllerProvider`.
class SyncController with WidgetsBindingObserver {
  SyncController(
    this._engine,
    this._auth, {
    this.onSyncingChanged,
    this.onFirstSyncCompleted,
    this.onSyncCompleted,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        // Sign-out wipes the local DB, so if another account signs in within
        // this same app session its restore must re-close the scanner gate:
        // re-arm the completer (only when already fired — pending waiters keep
        // the old one and resolve on the next successful sync).
        if (_initialSync.isCompleted) _initialSync = Completer<void>();
        _firstSyncRetriesLeft = _firstSyncRetries;
        _firstSyncCompletedFired = false;
        return;
      }
      _fullSync();
    });
    // Defer the launch-time sync out of the constructor (which runs during a
    // provider build) so its onSyncingChanged callback doesn't mutate another
    // provider mid-build.
    if (_auth.isSignedIn) scheduleMicrotask(_fullSync);
  }

  final SyncEngine _engine;
  final AuthService _auth;

  /// Called with `true` when the first full sync after start/sign-in begins and
  /// `false` when it finishes, so the UI can show a "loading your data" state on
  /// the first login of a new device (when the local DB is still empty).
  final void Function(bool syncing)? onSyncingChanged;

  /// Called once, after the first cloud sync that actually completes (pull + push
  /// ran), so callers can persist a "this device has synced" flag and never show
  /// the first-load skeleton again.
  final void Function()? onFirstSyncCompleted;

  /// Called after EVERY full sync that actually completes (not just the first),
  /// with the uid it ran for — for post-pull work that must track ongoing cloud
  /// changes, like materialising a profile photo edited on another device.
  final void Function(String uid)? onSyncCompleted;

  /// Upper bound on the first sync's contribution to the loading state: even if a
  /// Firestore call stalls, the skeleton is guaranteed to clear within this.
  static const _firstSyncTimeout = Duration(seconds: 15);

  /// Minimum gap between resume-triggered full syncs, so rapidly switching back
  /// to the app doesn't re-run a full sync every time. Sign-in and launch syncs
  /// are never throttled.
  static const _resumeMinInterval = Duration(minutes: 2);

  /// How many times a failed first sync is retried (beyond the normal
  /// triggers) while the scanner gate is still closed, and how long apart.
  /// A transient network error right after login would otherwise leave the
  /// gate closed until the next resume.
  static const _firstSyncRetries = 3;
  static const _firstSyncRetryGap = Duration(seconds: 8);

  /// How many times a debounced push that couldn't run (a full sync held the
  /// engine, or the network failed) is re-armed before giving up until the
  /// next trigger. Without this, an edit made while a full sync is in flight
  /// stays pending until some unrelated event pushes it.
  static const _pushRetries = 5;

  StreamSubscription<void>? _authSub;
  Timer? _debounce;
  Timer? _firstSyncRetry;
  int _pushRetriesLeft = 0;
  bool _firstSyncStarted = false;
  bool _firstSyncCompletedFired = false;
  int _firstSyncRetriesLeft = _firstSyncRetries;
  DateTime? _lastFullSyncAt;
  Completer<void> _initialSync = Completer<void>();

  /// Whether the first cloud sync since app start has *succeeded* (trivially
  /// true when signed out). While false for a signed-in user, the local DB may
  /// still be missing cloud rows — the slip scanner checks this before reading
  /// the gallery so it never re-imports slips a pending restore is about to
  /// deliver.
  bool get initialSyncCompleted =>
      !_auth.isSignedIn || _initialSync.isCompleted;

  /// Resolves once the first cloud sync since app start has succeeded (pull +
  /// push actually ran), or immediately when the user isn't signed in. A
  /// failed or timed-out attempt does NOT resolve this — a later attempt
  /// (retry, resume, sign-in) does — so callers must bound their wait.
  Future<void> awaitInitialSync() {
    if (!_auth.isSignedIn) return Future<void>.value();
    return _initialSync.future;
  }

  /// Push pending local changes after a (debounced) delay. Push-only does no
  /// reads, and markSynced leaves nothing pending, so repeated triggers
  /// converge instead of looping.
  void nudgePush() {
    _pushRetriesLeft = _pushRetries;
    _armPush(const Duration(seconds: 3));
  }

  void _armPush(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, () async {
      final ran = await _engine.pushOnly();
      // pushOnly is a no-op while a full sync holds the engine (and returns
      // false on a network error) — re-arm a bounded retry so the pending rows
      // aren't stranded until the next unrelated trigger.
      if (!ran && _auth.isSignedIn && _pushRetriesLeft > 0) {
        _pushRetriesLeft--;
        _armPush(const Duration(seconds: 5));
      }
    });
  }

  Future<void> _fullSync() async {
    // Only the invocation that owns the very first sync drives the loading flag,
    // so overlapping triggers (constructor + auth-state emission) can't flip it
    // off early. The flag is claimed synchronously before the first await.
    final ownsFirst = !_firstSyncStarted;
    if (ownsFirst) {
      _firstSyncStarted = true;
      onSyncingChanged?.call(true);
    }
    _lastFullSyncAt = DateTime.now();
    final uid = _auth.currentUser?.uid;
    final attempt = _engine.sync();
    // The scanner gate and the "this device has synced" flag track the *real*
    // outcome, never the time-boxed wait below: a first sync that outlives the
    // loading-state timeout still opens the gate when it eventually succeeds,
    // and a failed one keeps the gate closed (scanning before the restore has
    // landed would re-import slips as duplicates) and is retried instead.
    attempt.then((ran) {
      // A late result from before an account switch must not open the new
      // account's gate (its own restore hasn't run yet).
      if (uid == null || _auth.currentUser?.uid != uid) return;
      if (ran) {
        if (!_initialSync.isCompleted) _initialSync.complete();
        onSyncCompleted?.call(uid);
        // Persist "this device has synced" so a returning user never sees the
        // first-load skeleton again. Guarded to fire only once.
        if (!_firstSyncCompletedFired) {
          _firstSyncCompletedFired = true;
          onFirstSyncCompleted?.call();
        }
      } else {
        _scheduleFirstSyncRetry();
      }
    });
    try {
      // Bounded so a stalled Firestore call can't strand the loading skeleton
      // (the real sync keeps running; only the loading state is time-boxed).
      await attempt.timeout(_firstSyncTimeout);
    } catch (_) {
      // Best-effort; a failed sync is retried on the next trigger (resume /
      // sign-in), which will also unlock the scanner when it succeeds.
    } finally {
      if (ownsFirst) onSyncingChanged?.call(false);
    }
  }

  /// While the first successful sync is still outstanding, retry a failed
  /// attempt a few times. Checked again at fire time: by then the concurrent
  /// attempt that made this one a no-op may have opened the gate already.
  void _scheduleFirstSyncRetry() {
    if (_initialSync.isCompleted || !_auth.isSignedIn) return;
    if (_firstSyncRetriesLeft <= 0) return;
    _firstSyncRetriesLeft--;
    _firstSyncRetry?.cancel();
    _firstSyncRetry = Timer(_firstSyncRetryGap, () {
      if (!_initialSync.isCompleted && _auth.isSignedIn) _fullSync();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Throttle: skip if a full sync ran very recently (avoids re-syncing on
    // every quick app switch). On-change edits still upload via nudgePush.
    final last = _lastFullSyncAt;
    if (last != null && DateTime.now().difference(last) < _resumeMinInterval) {
      return;
    }
    _fullSync();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _debounce?.cancel();
    _firstSyncRetry?.cancel();
  }
}
