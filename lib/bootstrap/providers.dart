import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_date.dart';
import '../data/local/database.dart';
import '../data/remote/auth_service.dart';
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
      ref.watch(databaseProvider), FirebaseFirestore.instance, auth);
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
    lastSlipReadAt: () async =>
        (await ref.read(settingsRepositoryProvider).read()).lastSlipReadAt,
  );
});

/// Drives the automatic, one-gesture slip scan (pull-to-refresh on Home / FAB).
class ScanState {
  const ScanState({
    this.scanning = false,
    this.result,
    this.limited = false,
    this.permissionDenied = false,
    this.error,
  });

  final bool scanning;
  final ScanResult? result;
  final bool limited;
  final bool permissionDenied;
  final Object? error;
}

class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  bool _autoScanned = false;

  /// Trigger [scan] exactly once per app launch (called from Home on open).
  /// The flag lives on this app-lifetime provider, so revisiting Home via the
  /// bottom nav never re-fires it.
  Future<void> autoScanOnce() async {
    if (_autoScanned) return;
    _autoScanned = true;
    await scan();
  }

  /// Read every new slip image from the gallery automatically (no album pick).
  Future<void> scan() async {
    if (state.scanning) return;
    state = const ScanState(scanning: true);
    final importer = ref.read(slipImporterProvider);
    final perm = await importer.requestPermission();
    if (!perm.granted) {
      state = const ScanState(permissionDenied: true);
      return;
    }
    try {
      final result = await importer.scanNew();
      // Persist the scan's START time as the next incremental watermark, so a
      // photo saved *during* the scan is still picked up next run.
      await ref
          .read(settingsRepositoryProvider)
          .setLastSlipReadAt(result.scannedAtMs);
      state = ScanState(result: result, limited: perm.limited);
    } catch (e) {
      state = ScanState(error: e, limited: perm.limited);
    }
  }
}

final scanControllerProvider =
    NotifierProvider<ScanController, ScanState>(ScanController.new);

// ---- Reactive data ---------------------------------------------------------

final categoriesProvider = StreamProvider<List<CategoryRow>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchCategories(),
);

/// The month currently shown on Home / Stats.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() => AppDate.startOfMonth(DateTime.now());

  void set(DateTime month) => state = AppDate.startOfMonth(month);
  void next() => state = AppDate.addMonths(state, 1);
  void previous() => state = AppDate.addMonths(state, -1);
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

final monthTransactionsProvider = StreamProvider<List<TransactionRow>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(transactionRepositoryProvider).watchMonth(month);
});

/// A single transaction by id (Transaction detail screen).
final transactionByIdProvider =
    StreamProvider.family<TransactionRow?, String>((ref, id) {
  return ref.watch(databaseProvider).watchTransaction(id);
});

/// All transaction↔tag links (for resolving a transaction's tags reactively).
final allTransactionTagsProvider =
    StreamProvider<List<TransactionTagRow>>((ref) {
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
