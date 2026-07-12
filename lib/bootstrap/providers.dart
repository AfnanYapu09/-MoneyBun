import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_period.dart';
import '../data/local/database.dart';
import '../data/recurring/recurring_service.dart';
import '../data/remote/auth_service.dart';
import '../data/remote/sync_controller.dart';
import '../data/remote/sync_engine.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/slip_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../features/slip/data/slip_importer.dart';
import '../features/slip/data/slip_ocr_service.dart';
import '../features/slip/data/slip_pipeline.dart';
import '../features/slip/data/slip_qr_scanner.dart';

// ---- Infrastructure --------------------------------------------------------

/// The single Drift database (source of truth). Closed when the scope disposes.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Overridden in `main()` to `true` only when real Firebase config initialised.
final firebaseReadyProvider = Provider<bool>((ref) => false);

// ---- Repositories ----------------------------------------------------------

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);
final slipRepositoryProvider = Provider<SlipRepository>(
  (ref) => SlipRepository(ref.watch(databaseProvider)),
);
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);
final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => TagRepository(ref.watch(databaseProvider)),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Materialises due recurring rules into transactions (called once on launch).
final recurringServiceProvider = Provider<RecurringService>(
  (ref) => RecurringService(
    ref.watch(databaseProvider),
    ref.watch(transactionRepositoryProvider),
  ),
);

// ---- Firebase (null until real config is in place) -------------------------

final authServiceProvider = Provider<AuthService?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  return AuthService(FirebaseAuth.instance);
});

final syncEngineProvider = Provider<SyncEngine?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  final auth = ref.watch(authServiceProvider);
  if (auth == null) return null;
  return SyncEngine(
    ref.watch(databaseProvider),
    FirebaseFirestore.instance,
    auth,
  );
});

/// Whether the first cloud sync after sign-in is still running. Home watches
/// this to show a loading skeleton on a new device's first login (when the
/// local DB is empty and the user's data is still streaming down). Stays false
/// in guest / offline mode, where there is no cloud to wait for.
class InitialSyncing extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void setSyncing(bool value) => state = value;
}

final initialSyncingProvider =
    NotifierProvider<InitialSyncing, bool>(InitialSyncing.new);

/// Owns automatic sync (on sign-in, app launch, resume, and after edits).
/// Watch it once (in the app root) to keep it alive for the app's lifetime.
final syncControllerProvider = Provider<SyncController?>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final auth = ref.watch(authServiceProvider);
  if (engine == null || auth == null) return null;
  final controller = SyncController(
    engine,
    auth,
    onSyncingChanged: (syncing) =>
        ref.read(initialSyncingProvider.notifier).setSyncing(syncing),
    onFirstSyncCompleted: () =>
        ref.read(settingsRepositoryProvider).setFirstSyncDone(true),
  );
  // Upload pending changes shortly after any local data change.
  ref.listen(allTransactionsProvider, (_, __) => controller.nudgePush());
  ref.listen(accountsProvider, (_, __) => controller.nudgePush());
  ref.listen(categoriesProvider, (_, __) => controller.nudgePush());
  ref.listen(tagsProvider, (_, __) => controller.nudgePush());
  ref.listen(budgetsProvider, (_, __) => controller.nudgePush());
  ref.listen(recurringRulesProvider, (_, __) => controller.nudgePush());
  // Settings too: profile edits / savings goal / scan toggles sync per-key
  // (see SyncEngine._pushSettings). pushOnly leaves nothing pending, so the
  // stream events its own push causes converge instead of looping.
  ref.listen(appSettingsProvider, (_, __) => controller.nudgePush());
  ref.onDispose(controller.dispose);
  return controller;
});

final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authServiceProvider);
  if (auth == null) return Stream<User?>.value(null);
  return auth.authStateChanges();
});

// ---- Slip pipeline + importer ----------------------------------------------

final slipQrScannerProvider = Provider((ref) => SlipQrScanner());
final slipOcrServiceProvider = Provider((ref) => SlipOcrService());
final slipPipelineProvider = Provider(
  (ref) => SlipPipeline(
    ref.watch(slipQrScannerProvider),
    ref.watch(slipOcrServiceProvider),
  ),
);

final slipImporterProvider = Provider<SlipImporter>((ref) {
  final db = ref.watch(databaseProvider);
  return SlipImporter(
    pipeline: ref.watch(slipPipelineProvider),
    slips: ref.watch(slipRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    importedAssetIds: db.importedAssetIds,
    importedSlipRefs: db.importedSlipRefs,
    assetImported: db.slipAssetExists,
    refImported: db.slipRefExists,
    latestSlipPhotoTime: db.latestSlipPhotoTime,
    // Banks turned off in the accounts sheet (their scan-catalog ids).
    disabledScanIds: () async =>
        (await ref.read(settingsRepositoryProvider).read()).disabledScanIds,
    // Device-local "read this far" record (extra re-read guard).
    scannedUpTo: () => ref.read(settingsRepositoryProvider).getSlipScanUpTo(),
    saveScannedUpTo: (ms) =>
        ref.read(settingsRepositoryProvider).setSlipScanUpTo(ms),
  );
});

/// Drives the automatic, one-gesture slip scan (pull-to-refresh on Home / FAB).
class ScanState {
  const ScanState({
    this.scanning = false,
    this.result,
    this.limited = false,
    this.permissionDenied = false,
    this.waitingForRestore = false,
    this.error,
  });

  final bool scanning;
  final ScanResult? result;
  final bool limited;
  final bool permissionDenied;

  /// A fresh sign-in's cloud restore hasn't reached this device yet, so the
  /// scan was skipped (it re-runs automatically once the restore lands).
  final bool waitingForRestore;
  final Object? error;
}

class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  bool _autoScanned = false;
  bool _postRestoreScanArmed = false;

  /// Claimed synchronously on entry to [scan] — `state.scanning` alone can't
  /// stop a re-entrant call anymore because the restore gate check below
  /// awaits before the state flips (two overlapping scans would import the
  /// same photos twice).
  bool _scanBusy = false;

  /// How long an automatic launch scan waits for a fresh sign-in's first cloud
  /// pull before deferring (the restore usually lands within a few seconds).
  static const _restoreWait = Duration(seconds: 20);

  /// Trigger [scan] exactly once per app launch (called from Home on open).
  /// The flag lives on this app-lifetime provider, so revisiting Home via the
  /// bottom nav never re-fires it.
  Future<void> autoScanOnce() async {
    if (_autoScanned) return;
    _autoScanned = true;
    await scan(auto: true);
  }

  /// Read every new slip image from the gallery automatically (no album pick).
  ///
  /// After a fresh sign-in, scanning is deferred until the first successful
  /// cloud sync: the restored slips carry the dedup keys (asset ids, transRefs,
  /// watermark), so scanning before they land would re-import every recent slip
  /// as a duplicate. Automatic scans wait [_restoreWait] for it; a manual
  /// pull-to-refresh skips immediately (no dead gesture) — both re-run
  /// automatically the moment the restore completes.
  Future<void> scan({bool auto = false}) async {
    if (_scanBusy) return;
    _scanBusy = true;
    try {
      if (!await _restoreDone(waitFor: auto ? _restoreWait : Duration.zero)) {
        _armPostRestoreScan();
        state = const ScanState(waitingForRestore: true);
        return;
      }
      state = const ScanState(scanning: true);
      final importer = ref.read(slipImporterProvider);
      final perm = await importer.requestPermission();
      if (!perm.granted) {
        state = const ScanState(permissionDenied: true);
        return;
      }
      try {
        // The scan is cancelled if the signed-in user changes while it runs:
        // a sign-out wipes the local DB mid-scan, and imports written after
        // the wipe would sync into the *next* account's cloud.
        final startUid = ref.read(authServiceProvider)?.currentUser?.uid;
        bool sameUser() =>
            ref.read(authServiceProvider)?.currentUser?.uid == startUid;
        final result = await importer.scanNew(isCancelled: () => !sameUser());
        // Record when the scan ran — for the "last read at" label only. The
        // scanner reads only slips newer than the last imported one and dedups
        // by asset id, so this timestamp is display-only and never gates
        // scanning. Skipped after an account switch (it belongs to the old
        // account and would leak onto the next one's fresh settings).
        if (sameUser()) {
          await ref
              .read(settingsRepositoryProvider)
              .setLastSlipReadAt(DateTime.now().millisecondsSinceEpoch);
        }
        state = ScanState(result: result, limited: perm.limited);
      } catch (e) {
        state = ScanState(error: e, limited: perm.limited);
      }
    } finally {
      _scanBusy = false;
    }
  }

  /// Whether it is safe to read the gallery: this device has already finished
  /// a first cloud sync at some point (its slips table is authoritative, so
  /// dedup works even while a routine sync is still running), or the pending
  /// first sync completes within [waitFor]. Guest mode is always safe.
  Future<bool> _restoreDone({required Duration waitFor}) async {
    final sync = ref.read(syncControllerProvider);
    if (sync == null || sync.initialSyncCompleted) return true;
    final settings = await ref.read(settingsRepositoryProvider).read();
    if (settings.firstSyncDone) return true;
    if (waitFor > Duration.zero) {
      await sync.awaitInitialSync().timeout(waitFor, onTimeout: () {});
    }
    return sync.initialSyncCompleted;
  }

  /// Re-run the scan as soon as the pending restore lands, so a skipped scan
  /// (auto or manual) never silently goes missing. Armed at most once per
  /// pending restore; disarmed when it fires so a later account switch (whose
  /// scans get skipped again) can re-arm.
  void _armPostRestoreScan() {
    if (_postRestoreScanArmed) return;
    _postRestoreScanArmed = true;
    final sync = ref.read(syncControllerProvider);
    if (sync == null) return;
    unawaited(sync.awaitInitialSync().then((_) {
      _postRestoreScanArmed = false;
      return scan(auto: true);
    }).catchError((_) {
      // The container was torn down (app shutdown) before the restore landed —
      // nothing to scan for anymore; never surface as an unhandled error.
    }));
  }
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);

/// Silent photo-permission status driving the Home permission banner. Refresh
/// on Home entry and on every lifecycle resume; never prompts the user.
enum PhotoPermStatus { unknown, granted, limited, denied }

class PhotoPermission extends Notifier<PhotoPermStatus> {
  @override
  PhotoPermStatus build() => PhotoPermStatus.unknown;

  Future<void> refresh() async {
    final p = await ref.read(slipImporterProvider).checkPermission();
    state = p.granted
        ? (p.limited ? PhotoPermStatus.limited : PhotoPermStatus.granted)
        : PhotoPermStatus.denied;
  }

  /// Called from the scan-denied edge so the banner appears immediately
  /// without waiting for the next silent check.
  void markDenied() => state = PhotoPermStatus.denied;
}

final photoPermissionProvider =
    NotifierProvider<PhotoPermission, PhotoPermStatus>(PhotoPermission.new);

/// Once-per-process guard so the styled photo-permission dialog nags on every
/// app launch but not on every Home revisit within one session (the banner
/// stays persistent instead). Mirrors ScanController._autoScanned.
class PermDialogShown extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;
}

final permDialogShownProvider =
    NotifierProvider<PermDialogShown, bool>(PermDialogShown.new);

/// One-shot signal from Settings → Home asking to replay the walkthrough.
class TourReplay extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;
  void clear() => state = false;
}

final tourReplayProvider = NotifierProvider<TourReplay, bool>(TourReplay.new);

// ---- Reactive data ---------------------------------------------------------

final categoriesProvider = StreamProvider<List<CategoryRow>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchCategories(),
);

/// The time window (month or week) shown across Home / Stats / Budget /
/// All-transactions. A single global filter so switching it on one screen
/// reflects on every other.
class SelectedPeriod extends Notifier<DatePeriod> {
  @override
  DatePeriod build() => DatePeriod.month(DateTime.now());

  void setMonth(DateTime month) => state = DatePeriod.month(month);
  void setWeek(DateTime dayInWeek) => state = DatePeriod.week(dayInWeek);
  void setYear(DateTime yearIn) => state = DatePeriod.year(yearIn);
  void next() => state = state.next();
  void previous() => state = state.previous();
}

final selectedPeriodProvider = NotifierProvider<SelectedPeriod, DatePeriod>(
  SelectedPeriod.new,
);

/// Number of modal bottom sheets currently open. The home FAB hides while > 0
/// so the floating "+" doesn't peek behind an open popup.
class OpenSheets extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
  void decrement() => state = state > 0 ? state - 1 : 0;
}

final openSheetsProvider = NotifierProvider<OpenSheets, int>(OpenSheets.new);

/// Transactions inside the selected period (month or week).
final periodTransactionsProvider = StreamProvider<List<TransactionRow>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchBetween(period.start, period.end);
});

/// Transactions for the calendar month the period sits in — for month-only
/// views (Savings goal) that ignore week mode.
final monthTransactionsProvider = StreamProvider<List<TransactionRow>>((ref) {
  final month = ref.watch(selectedPeriodProvider).monthAnchor;
  return ref.watch(transactionRepositoryProvider).watchMonth(month);
});

/// A single transaction by id (Transaction detail screen). autoDispose: a
/// plain family would keep one live stream per id ever watched.
final transactionByIdProvider =
    StreamProvider.autoDispose.family<TransactionRow?, String>((
  ref,
  id,
) {
  return ref.watch(databaseProvider).watchTransaction(id);
});

/// All transaction↔tag links (for resolving a transaction's tags reactively).
final allTransactionTagsProvider = StreamProvider<List<TransactionTagRow>>((
  ref,
) {
  return ref.watch(databaseProvider).watchAllTransactionTags();
});

/// All active transactions (Search).
final allTransactionsProvider = StreamProvider<List<TransactionRow>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAll(),
);

/// All accounts/wallets (Accounts sheet, account pickers).
final accountsProvider = StreamProvider<List<AccountRow>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAccounts(),
);

/// User-defined tags.
final tagsProvider = StreamProvider<List<TagRow>>(
  (ref) => ref.watch(tagRepositoryProvider).watchTags(),
);

/// Tag id → usage count (Manage Tags).
final tagUsageProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(tagRepositoryProvider).watchUsageCounts(),
);

/// All budgets (Budget screen / Stats).
final budgetsProvider = StreamProvider<List<BudgetRow>>(
  (ref) => ref.watch(databaseProvider).watchBudgets(),
);

/// All recurring rules (Manage Recurring screen).
final recurringRulesProvider = StreamProvider<List<RecurringRuleRow>>(
  (ref) => ref.watch(databaseProvider).watchRecurringRules(),
);

// ---- Settings (persisted in Drift, single source of truth) -----------------

/// Reactive snapshot of all app settings.
final appSettingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// App locale (derived from settings; Thai by default).
final localeProvider = Provider<Locale>((ref) {
  final code = ref.watch(appSettingsProvider).value?.locale ?? 'th';
  return Locale(code);
});

/// Whether onboarding has been completed (drives the router redirect).
final onboardingSeenProvider = Provider<bool>(
  (ref) => ref.watch(appSettingsProvider).value?.onboardingSeen ?? false,
);
