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
  }) {
    WidgetsBinding.instance.addObserver(this);
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) _fullSync();
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

  /// Upper bound on the first sync's contribution to the loading state: even if a
  /// Firestore call stalls, the skeleton is guaranteed to clear within this.
  static const _firstSyncTimeout = Duration(seconds: 15);

  /// Minimum gap between resume-triggered full syncs, so rapidly switching back
  /// to the app doesn't re-run a full sync every time. Sign-in and launch syncs
  /// are never throttled.
  static const _resumeMinInterval = Duration(minutes: 2);

  StreamSubscription<void>? _authSub;
  Timer? _debounce;
  bool _firstSyncStarted = false;
  bool _firstSyncCompletedFired = false;
  DateTime? _lastFullSyncAt;
  final Completer<void> _initialSync = Completer<void>();

  /// Resolves once the first cloud sync has finished (success or failure), or
  /// immediately when the user isn't signed in. The slip scanner awaits this so
  /// it never reads slips that are about to be pulled from the cloud.
  Future<void> awaitInitialSync() {
    if (!_auth.isSignedIn) return Future<void>.value();
    return _initialSync.future;
  }

  /// Push pending local changes after a (debounced) delay. Push-only does no
  /// reads, and markSynced leaves nothing pending, so repeated triggers
  /// converge instead of looping.
  void nudgePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _engine.pushOnly);
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
    var ran = false;
    try {
      // Bounded so a stalled Firestore call can't strand the loading skeleton
      // (the real sync keeps running; only the loading state is time-boxed).
      ran = await _engine.sync().timeout(_firstSyncTimeout);
    } catch (_) {
      // Best-effort; a failed / timed-out sync is retried on the next trigger.
    } finally {
      // Unblock the slip scanner after the first sync, even if it failed.
      if (!_initialSync.isCompleted) _initialSync.complete();
      if (ownsFirst) onSyncingChanged?.call(false);
      // Persist "this device has synced" once a sync actually ran, so a returning
      // user never sees the first-load skeleton again. Fired by whichever call
      // did the real work (ran == true), guarded to fire only once.
      if (ran && !_firstSyncCompletedFired) {
        _firstSyncCompletedFired = true;
        onFirstSyncCompleted?.call();
      }
    }
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
  }
}
