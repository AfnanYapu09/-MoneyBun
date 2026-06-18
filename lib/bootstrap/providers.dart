import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_date.dart';
import '../data/local/database.dart';
import '../data/remote/auth_service.dart';
import '../data/remote/slip_verify_api.dart';
import '../data/remote/sync_engine.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/slip_repository.dart';
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

final slipVerifyApiProvider = Provider<SlipVerifyApi?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  return SlipVerifyApi(FirebaseFunctions.instance);
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

/// Slips keyed by id, so an entry can show its image thumbnail + details.
final slipsByIdProvider = StreamProvider<Map<String, SlipRow>>((ref) {
  return ref
      .watch(slipRepositoryProvider)
      .watchAll()
      .map((list) => {for (final s in list) s.id: s});
});

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

/// App locale (Thai by default), switchable from Settings.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('th');
  void set(Locale locale) => state = locale;
}

final localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// Whether the optional online slip-verify API may be called. Off by default.
class SlipApiEnabled extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final slipApiEnabledProvider =
    NotifierProvider<SlipApiEnabled, bool>(SlipApiEnabled.new);
