import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'sync_engine.dart';

/// Drives automatic sync so the user never has to tap "Sync now":
/// - a full sync (push + pull) when the user signs in, when this controller
///   starts while already signed in, and whenever the app returns to the
///   foreground;
/// - a cheap push-only sync (no Firestore reads) shortly after any local data
///   change, debounced so a burst of edits uploads once. The change signal is
///   wired up by [syncControllerProvider] via `ref.listen`.
///
/// Kept alive for the app's lifetime by watching `syncControllerProvider`.
class SyncController with WidgetsBindingObserver {
  SyncController(this._engine, this._auth) {
    WidgetsBinding.instance.addObserver(this);
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) _fullSync();
    });
    if (_auth.isSignedIn) _fullSync();
  }

  final SyncEngine _engine;
  final AuthService _auth;

  StreamSubscription<void>? _authSub;
  Timer? _debounce;

  /// Push pending local changes after a (debounced) delay. Push-only does no
  /// reads, and markSynced leaves nothing pending, so repeated triggers
  /// converge instead of looping.
  void nudgePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _engine.pushOnly);
  }

  Future<void> _fullSync() async {
    try {
      await _engine.sync();
    } catch (_) {
      // Best-effort; a failed sync is retried on the next trigger.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fullSync();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _debounce?.cancel();
  }
}
