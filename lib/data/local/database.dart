import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants/category_seed.dart';
import '../../domain/enums/enums.dart';
import 'tables/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Accounts, Categories, Transactions, Slips, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
          driftDatabase(
            name: 'moneybun',
            // Web support: sqlite3.wasm + drift_worker.js are served from web/.
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
        );

  /// In-memory / custom executor constructor for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          // v2: store slip images cross-platform (base64) + gallery asset id.
          if (from < 2) {
            await m.addColumn(slips, slips.imageBase64);
            await m.addColumn(slips, slips.assetId);
          }
        },
      );

  /// Seed the flat category list on first run. No accounts are seeded — the app
  /// is slip-first and has no wallet/account concept.
  Future<void> _seed() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      b.insertAll(
        categories,
        [
          for (var i = 0; i < SeedData.categories.length; i++)
            _categoryFromSeed(SeedData.categories[i], i, now),
        ],
      );
    });
  }

  CategoriesCompanion _categoryFromSeed(CategorySeed s, int order, int now) =>
      CategoriesCompanion.insert(
        id: s.id,
        name: s.nameTh,
        type: s.type,
        nameEn: Value(s.nameEn),
        iconKey: Value(s.iconKey),
        colorHex: Value(s.colorHex),
        isSystem: const Value(true),
        sortOrder: Value(order),
        createdAt: now,
        updatedAt: now,
        // Seed rows start pending; they get pushed once the user signs in.
        syncStatus: const Value(SyncStatus.pendingCreate),
      );

  // ---- Accounts ----------------------------------------------------------

  Stream<List<AccountRow>> watchAccounts() {
    return (select(accounts)
          ..where((a) => a.deleted.equals(false))
          ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
        .watch();
  }

  Future<List<AccountRow>> getAccounts() {
    return (select(accounts)..where((a) => a.deleted.equals(false))).get();
  }

  Future<AccountRow?> getAccount(String id) {
    return (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertAccount(AccountsCompanion row) =>
      into(accounts).insertOnConflictUpdate(row);

  // ---- Categories --------------------------------------------------------

  Stream<List<CategoryRow>> watchCategories() {
    return (select(categories)
          ..where((c) => c.deleted.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .watch();
  }

  Future<List<CategoryRow>> getCategories() {
    return (select(categories)..where((c) => c.deleted.equals(false))).get();
  }

  Future<void> upsertCategory(CategoriesCompanion row) =>
      into(categories).insertOnConflictUpdate(row);

  // ---- Transactions ------------------------------------------------------

  Stream<List<TransactionRow>> watchTransactionsBetween(
      int startMs, int endMs) {
    return (select(transactions)
          ..where((t) =>
              t.deleted.equals(false) &
              t.occurredAt.isBetweenValues(startMs, endMs))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<TransactionRow>> watchActiveTransactions() {
    return (select(transactions)..where((t) => t.deleted.equals(false)))
        .watch();
  }

  Future<List<TransactionRow>> getActiveTransactions() {
    return (select(transactions)..where((t) => t.deleted.equals(false))).get();
  }

  Future<TransactionRow?> getTransaction(String id) {
    return (select(transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertTransaction(TransactionsCompanion row) =>
      into(transactions).insertOnConflictUpdate(row);

  /// Soft-delete: mark deleted + pending so the delete syncs, then GC later.
  Future<void> softDeleteTransaction(String id, int now) {
    return (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingDelete),
        updatedAt: Value(now),
      ),
    );
  }

  // ---- Slips -------------------------------------------------------------

  Future<void> upsertSlip(SlipsCompanion row) =>
      into(slips).insertOnConflictUpdate(row);

  Future<SlipRow?> getSlip(String id) =>
      (select(slips)..where((s) => s.id.equals(id))).getSingleOrNull();

  Stream<List<SlipRow>> watchSlips() =>
      (select(slips)..where((s) => s.deleted.equals(false))).watch();

  /// Asset ids already imported (Android album scan dedup).
  Future<Set<String>> importedAssetIds() async {
    final query = selectOnly(slips)
      ..addColumns([slips.assetId])
      ..where(slips.assetId.isNotNull());
    final rows = await query.get();
    return rows.map((r) => r.read(slips.assetId)).whereType<String>().toSet();
  }

  // ---- Budgets -----------------------------------------------------------

  Stream<List<BudgetRow>> watchBudgets() {
    return (select(budgets)..where((b) => b.deleted.equals(false))).watch();
  }

  Future<void> upsertBudget(BudgetsCompanion row) =>
      into(budgets).insertOnConflictUpdate(row);

  // ---- Sync helpers ------------------------------------------------------

  Future<List<TransactionRow>> pendingTransactions() => (select(transactions)
        ..where((t) => t.syncStatus.isNotValue(SyncStatus.synced.index)))
      .get();

  Future<List<AccountRow>> pendingAccounts() => (select(accounts)
        ..where((a) => a.syncStatus.isNotValue(SyncStatus.synced.index)))
      .get();

  Future<List<CategoryRow>> pendingCategories() => (select(categories)
        ..where((c) => c.syncStatus.isNotValue(SyncStatus.synced.index)))
      .get();

  Future<List<SlipRow>> pendingSlips() => (select(slips)
        ..where((s) => s.syncStatus.isNotValue(SyncStatus.synced.index)))
      .get();

  Future<void> markTransactionSynced(String id) => (update(transactions)
        ..where((t) => t.id.equals(id)))
      .write(const TransactionsCompanion(syncStatus: Value(SyncStatus.synced)));

  Future<void> markAccountSynced(String id) =>
      (update(accounts)..where((a) => a.id.equals(id)))
          .write(const AccountsCompanion(syncStatus: Value(SyncStatus.synced)));

  Future<void> markCategorySynced(String id) => (update(categories)
        ..where((c) => c.id.equals(id)))
      .write(const CategoriesCompanion(syncStatus: Value(SyncStatus.synced)));

  Future<void> markSlipSynced(String id) =>
      (update(slips)..where((s) => s.id.equals(id)))
          .write(const SlipsCompanion(syncStatus: Value(SyncStatus.synced)));
}
