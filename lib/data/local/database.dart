import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants/account_seed.dart';
import '../../core/constants/category_seed.dart';
import '../../domain/enums/enums.dart';
import 'tables/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Transactions,
  Slips,
  Budgets,
  Tags,
  TransactionTags,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'moneybun'));

  /// In-memory / custom executor constructor for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
          await _seedAccounts();
        },
        onUpgrade: (m, from, to) async {
          // v2: track the source gallery asset id to skip re-importing slips.
          if (from < 2) {
            await m.addColumn(slips, slips.assetId);
          }
          // v3: tags, settings, watched accounts + the new design's data.
          if (from < 3) {
            await m.createTable(tags);
            await m.createTable(transactionTags);
            await m.createTable(settings);
            await m.addColumn(accounts, accounts.watchedForSlips);
            await _seedAccounts();
            // Existing users must NOT be forced through onboarding/login.
            await setSetting('onboardingSeen', 'true');
            await setSetting('authMode', 'guest');
          }
          // v4: income categories + extra expense defaults (idempotent re-seed).
          if (from < 4) {
            await _seedCategories();
          }
          // v5: Bun pixel-art icons. Add the new main-set categories
          // (insertOrIgnore) and re-skin carried-over system categories so they
          // render the new pixel glyphs + accent colours (names are preserved).
          if (from < 5) {
            await _seedCategories();
            await _reskinSystemCategories();
          }
          // v6: remember each slip's source-photo time so the scan watermark
          // (read only slips newer than the latest one) survives reinstall/sync.
          if (from < 6) {
            await m.addColumn(slips, slips.photoTakenAt);
          }
        },
      );

  /// Seed the expense + income category lists. Idempotent (insertOrIgnore on the
  /// stable `sys_` ids), so it is safe to re-run on upgrade to add new defaults
  /// without touching existing or user-renamed rows. Each list is ordered from 0.
  Future<void> _seedCategories() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      b.insertAll(
        categories,
        [
          for (var i = 0; i < SeedData.categories.length; i++)
            _categoryFromSeed(SeedData.categories[i], i, now),
          for (var i = 0; i < SeedData.incomeCategories.length; i++)
            _categoryFromSeed(SeedData.incomeCategories[i], i, now),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Re-skin carried-over system categories to the current seed's pixel glyph +
  /// accent colour (used by the v5 upgrade). Only touches `isSystem` rows and
  /// only their icon/colour/nameEn — the user's name is left untouched.
  Future<void> _reskinSystemCategories() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in [...SeedData.categories, ...SeedData.incomeCategories]) {
      await (update(categories)
            ..where((c) => c.id.equals(s.id) & c.isSystem.equals(true)))
          .write(CategoriesCompanion(
        iconKey: Value(s.iconKey),
        colorHex: Value(s.colorHex),
        nameEn: Value(s.nameEn),
        updatedAt: Value(now),
        syncStatus: const Value(SyncStatus.pendingUpdate),
      ));
    }
  }

  /// Seed default accounts/wallets (idempotent via stable ids + insertOrIgnore).
  Future<void> _seedAccounts() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      b.insertAll(
        accounts,
        [
          for (var i = 0; i < AccountSeedData.accounts.length; i++)
            _accountFromSeed(AccountSeedData.accounts[i], i, now),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  AccountsCompanion _accountFromSeed(AccountSeed s, int order, int now) =>
      AccountsCompanion.insert(
        id: s.id,
        name: s.nameTh,
        type: s.type,
        bankCode: Value(s.bankCode),
        iconKey: Value(s.iconKey),
        colorHex: Value(s.colorHex),
        sortOrder: Value(order),
        createdAt: now,
        updatedAt: now,
        syncStatus: const Value(SyncStatus.pendingCreate),
      );

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

  /// Unfiltered single-row fetch (includes soft-deleted rows) — used by sync's
  /// last-write-wins check so a local delete isn't resurrected by a pull.
  Future<CategoryRow?> getCategory(String id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> upsertCategory(CategoriesCompanion row) =>
      into(categories).insertOnConflictUpdate(row);

  /// Persist a new category order: rewrite each row's `sortOrder` to its index
  /// in [idsInOrder]. Done in one batch so the list reorders atomically.
  Future<void> reorderCategories(List<String> idsInOrder) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      for (var i = 0; i < idsInOrder.length; i++) {
        final id = idsInOrder[i];
        final order = i;
        b.update(
          categories,
          CategoriesCompanion(
            sortOrder: Value(order),
            updatedAt: Value(now),
            syncStatus: const Value(SyncStatus.pendingUpdate),
          ),
          where: (c) => c.id.equals(id),
        );
      }
    });
  }

  /// Soft-delete a category (mark deleted + pending so the delete syncs).
  Future<void> deleteCategory(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        deleted: const Value(true),
        updatedAt: Value(now),
        syncStatus: const Value(SyncStatus.pendingDelete),
      ),
    );
  }

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

  Stream<TransactionRow?> watchTransaction(String id) {
    return (select(transactions)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
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

  /// The source-photo time (epoch ms) of the most recently imported slip, or
  /// null when none have been imported. Drives the scan watermark: the scanner
  /// reads only photos newer than this, so it continues after the latest slip
  /// instead of re-reading old ones — and because [Slips.photoTakenAt] syncs,
  /// this survives a sign-out/reinstall (it is recomputed from restored data).
  Future<int?> latestSlipPhotoTime() async {
    final query = select(slips)
      ..where((s) => s.deleted.equals(false) & s.photoTakenAt.isNotNull())
      ..orderBy([(s) => OrderingTerm.desc(s.photoTakenAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.photoTakenAt;
  }

  /// Stable bank transaction references already imported. Used as a second
  /// dedup key so the same slip is not re-imported after a cloud restore (where
  /// the gallery asset id may be missing or differ).
  Future<Set<String>> importedSlipRefs() async {
    final query = selectOnly(slips)
      ..addColumns([slips.transRef])
      ..where(slips.transRef.isNotNull() & slips.deleted.equals(false));
    final rows = await query.get();
    return rows
        .map((r) => r.read(slips.transRef))
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  // ---- Budgets -----------------------------------------------------------

  Stream<List<BudgetRow>> watchBudgets() {
    return (select(budgets)..where((b) => b.deleted.equals(false))).watch();
  }

  Future<void> upsertBudget(BudgetsCompanion row) =>
      into(budgets).insertOnConflictUpdate(row);

  /// Soft-delete: mark deleted + pending so the delete syncs, then GC later.
  Future<void> softDeleteBudget(String id, int now) {
    return (update(budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        deleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingDelete),
        updatedAt: Value(now),
      ),
    );
  }

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

  Future<List<BudgetRow>> pendingBudgets() => (select(budgets)
        ..where((b) => b.syncStatus.isNotValue(SyncStatus.synced.index)))
      .get();

  Future<BudgetRow?> getBudget(String id) =>
      (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<void> markBudgetSynced(String id) =>
      (update(budgets)..where((b) => b.id.equals(id)))
          .write(const BudgetsCompanion(syncStatus: Value(SyncStatus.synced)));

  Future<List<TagRow>> pendingTags() => (select(tags)
        ..where((t) => t.syncStatus.isNotValue(SyncStatus.synced.index)))
      .get();

  Future<TagRow?> getTag(String id) =>
      (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> markTagSynced(String id) =>
      (update(tags)..where((t) => t.id.equals(id)))
          .write(const TagsCompanion(syncStatus: Value(SyncStatus.synced)));

  // ---- Bulk pull helpers (write a whole collection in one batch) ----------

  /// Local updatedAt keyed by transaction id — one query, so the pull doesn't
  /// read every row individually before deciding what to upsert.
  Future<Map<String, int>> transactionsUpdatedAt() async {
    final q = selectOnly(transactions)
      ..addColumns([transactions.id, transactions.updatedAt]);
    final rows = await q.get();
    return {
      for (final r in rows)
        r.read(transactions.id)!: r.read(transactions.updatedAt) ?? 0
    };
  }

  // Each of these selects every row (including soft-deleted ones) so the pull
  // can decide what to upsert from a single query instead of one read per
  // remote doc — and a locally-deleted row isn't resurrected, since its
  // tombstone's updatedAt is still in the map.
  Future<Map<String, int>> accountsUpdatedAt() async {
    final q = selectOnly(accounts)
      ..addColumns([accounts.id, accounts.updatedAt]);
    final rows = await q.get();
    return {
      for (final r in rows)
        r.read(accounts.id)!: r.read(accounts.updatedAt) ?? 0
    };
  }

  Future<Map<String, int>> categoriesUpdatedAt() async {
    final q = selectOnly(categories)
      ..addColumns([categories.id, categories.updatedAt]);
    final rows = await q.get();
    return {
      for (final r in rows)
        r.read(categories.id)!: r.read(categories.updatedAt) ?? 0
    };
  }

  Future<Map<String, int>> tagsUpdatedAt() async {
    final q = selectOnly(tags)..addColumns([tags.id, tags.updatedAt]);
    final rows = await q.get();
    return {
      for (final r in rows) r.read(tags.id)!: r.read(tags.updatedAt) ?? 0
    };
  }

  Future<Map<String, int>> budgetsUpdatedAt() async {
    final q = selectOnly(budgets)..addColumns([budgets.id, budgets.updatedAt]);
    final rows = await q.get();
    return {
      for (final r in rows) r.read(budgets.id)!: r.read(budgets.updatedAt) ?? 0
    };
  }

  Future<Map<String, int>> slipsUpdatedAt() async {
    final q = selectOnly(slips)..addColumns([slips.id, slips.updatedAt]);
    final rows = await q.get();
    return {
      for (final r in rows) r.read(slips.id)!: r.read(slips.updatedAt) ?? 0
    };
  }

  // insertAllOnConflictUpdate only writes the provided columns, so columns the
  // sync mappers omit (e.g. a slip's local imagePath) are preserved.
  Future<void> batchUpsertTransactions(List<TransactionsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(transactions, rows));

  Future<void> batchUpsertAccounts(List<AccountsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(accounts, rows));

  Future<void> batchUpsertCategories(List<CategoriesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(categories, rows));

  Future<void> batchUpsertTags(List<TagsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(tags, rows));

  Future<void> batchUpsertBudgets(List<BudgetsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(budgets, rows));

  Future<void> batchUpsertSlips(List<SlipsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(slips, rows));

  // ---- Tags (local-only) -------------------------------------------------

  Stream<List<TagRow>> watchTags() => (select(tags)
        ..where((t) => t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
      .watch();

  Future<List<TagRow>> getTags() =>
      (select(tags)..where((t) => t.deleted.equals(false))).get();

  Future<void> upsertTag(TagsCompanion row) =>
      into(tags).insertOnConflictUpdate(row);

  Future<void> deleteTagCascade(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (delete(transactionTags)..where((l) => l.tagId.equals(id))).go();
    // Soft-delete (not hard) so the deletion syncs as a tombstone and the tag
    // isn't resurrected by the next pull from the cloud.
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        deleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingDelete),
        updatedAt: Value(now),
      ),
    );
  }

  // ---- Transaction ↔ Tag links (local-only) ------------------------------

  Stream<List<TransactionTagRow>> watchAllTransactionTags() =>
      select(transactionTags).watch();

  Future<List<TransactionTagRow>> getAllTransactionTags() =>
      select(transactionTags).get();

  Future<List<String>> tagIdsForTransaction(String txnId) async {
    final rows = await (select(transactionTags)
          ..where((l) => l.transactionId.equals(txnId)))
        .get();
    return rows.map((r) => r.tagId).toList();
  }

  /// Replace the tag set for a transaction atomically.
  Future<void> setTransactionTags(String txnId, List<String> tagIds) async {
    await transaction(() async {
      await (delete(transactionTags)
            ..where((l) => l.transactionId.equals(txnId)))
          .go();
      for (final tagId in tagIds) {
        await into(transactionTags).insert(
          TransactionTagsCompanion.insert(transactionId: txnId, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  // ---- Settings (key/value, local-only) ----------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<List<SettingRow>> watchSettings() => select(settings).watch();

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
}
