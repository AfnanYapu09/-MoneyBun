import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/data/local/database.dart';
import 'package:moneybun/data/repositories/tag_repository.dart';
import 'package:moneybun/data/repositories/transaction_repository.dart';
import 'package:moneybun/domain/enums/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('onCreate seeds categories and accounts (schema v4)', () async {
    final categories = await db.getCategories();
    final accounts = await db.getAccounts();
    expect(categories, isNotEmpty);
    expect(accounts, isNotEmpty);
    // Both expense and income defaults are seeded.
    expect(categories.any((c) => c.type == CategoryType.expense), isTrue);
    expect(categories.any((c) => c.type == CategoryType.income), isTrue);
    // Default accounts are watched for slips by default.
    expect(accounts.every((a) => a.watchedForSlips), isTrue);
  });

  test('settings key/value round-trips', () async {
    expect(await db.getSetting('themeMode'), isNull);
    await db.setSetting('themeMode', 'dark');
    expect(await db.getSetting('themeMode'), 'dark');
  });

  test('save() persists a full transaction with tags', () async {
    final repo = TransactionRepository(db);
    await db.upsertTag(
      TagsCompanion.insert(
        id: 't1',
        name: 'จำเป็น',
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    final id = await repo.save(
      type: TxnType.expense,
      amountCents: 84550,
      categoryId: 'sys_food',
      note: 'lunch',
      occurredAt: DateTime(2026, 6, 18, 12, 30),
      tagIds: ['t1'],
    );
    final row = await repo.get(id);
    expect(row, isNotNull);
    expect(row!.type, TxnType.expense);
    expect(row.amountCents, 84550);
    expect(await repo.tagIds(id), ['t1']);
  });

  test('slip-import defaults keep working (type=expense)', () async {
    final repo = TransactionRepository(db);
    final id = await repo.save(
      amountCents: 12000,
      occurredAt: DateTime(2026, 6, 1),
    );
    final row = await repo.get(id);
    expect(row!.type, TxnType.expense);
    expect(row.accountId, '');
  });

  test('pull watermark round-trips and defaults to 0', () async {
    expect(await db.pullWatermark('transactions'), 0);
    await db.setPullWatermark('transactions', 1234);
    expect(await db.pullWatermark('transactions'), 1234);
    // Independent per collection.
    expect(await db.pullWatermark('accounts'), 0);
  });

  test('gcTombstones drops only old synced tombstones', () async {
    // A synced tombstone older than the cutoff → collected.
    await db.upsertTransaction(
      TransactionsCompanion.insert(
        id: 'gc_old',
        type: TxnType.expense,
        amountCents: 100,
        accountId: '',
        occurredAt: 0,
        createdAt: 0,
        updatedAt: 1000,
        deleted: const Value(true),
        syncStatus: const Value(SyncStatus.synced),
      ),
    );
    // A synced tombstone newer than the cutoff → kept.
    await db.upsertTransaction(
      TransactionsCompanion.insert(
        id: 'gc_recent',
        type: TxnType.expense,
        amountCents: 100,
        accountId: '',
        occurredAt: 0,
        createdAt: 0,
        updatedAt: 9000,
        deleted: const Value(true),
        syncStatus: const Value(SyncStatus.synced),
      ),
    );
    // An old tombstone that hasn't synced yet → kept (delete not propagated).
    await db.upsertTransaction(
      TransactionsCompanion.insert(
        id: 'gc_pending',
        type: TxnType.expense,
        amountCents: 100,
        accountId: '',
        occurredAt: 0,
        createdAt: 0,
        updatedAt: 1000,
        deleted: const Value(true),
        syncStatus: const Value(SyncStatus.pendingDelete),
      ),
    );
    // A live row → kept.
    final repo = TransactionRepository(db);
    final liveId = await repo.save(
      amountCents: 500,
      occurredAt: DateTime(2026, 6, 1),
    );

    await db.gcTombstones(5000);

    expect(await db.getTransaction('gc_old'), isNull);
    expect(await db.getTransaction('gc_recent'), isNotNull);
    expect(await db.getTransaction('gc_pending'), isNotNull);
    expect(await db.getTransaction(liveId), isNotNull);
  });

  test('renaming a synced tag flags it for push and keeps createdAt', () async {
    final tags = TagRepository(db);
    final id = await tags.save(name: 'Food');
    final saved = await db.getTag(id);
    await db.markTagSynced(id, saved!.updatedAt);
    final before = await db.getTag(id);
    expect(before!.syncStatus, SyncStatus.synced);

    await tags.save(id: id, name: 'Groceries');
    final after = await db.getTag(id);
    expect(after!.name, 'Groceries');
    // The rename must re-enter the pending queue or it never uploads.
    expect(after.syncStatus, SyncStatus.pendingUpdate);
    expect((await db.pendingTags()).map((t) => t.id), contains(id));
    // …and the edit must not clobber the original metadata.
    expect(after.createdAt, before.createdAt);
    expect(after.sortOrder, before.sortOrder);
  });

  test('renaming a tag that never synced stays pendingCreate', () async {
    final tags = TagRepository(db);
    final id = await tags.save(name: 'Trip');
    await tags.save(id: id, name: 'Travel');
    expect((await db.getTag(id))!.syncStatus, SyncStatus.pendingCreate);
  });

  test('markTransactionSynced is a compare-and-set on updatedAt', () async {
    final repo = TransactionRepository(db);
    final id = await repo.save(
      amountCents: 500,
      occurredAt: DateTime(2026, 6, 1),
    );
    final pushed = (await db.getTransaction(id))!;

    // The user edits the row while its upload is still in flight…
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.save(
      id: id,
      amountCents: 700,
      occurredAt: DateTime(2026, 6, 1),
    );

    // …so the late markSynced (carrying the pre-edit updatedAt) must MISS and
    // leave the row pending; stamping it synced would lose the edit forever.
    await db.markTransactionSynced(id, pushed.updatedAt);
    final after = (await db.getTransaction(id))!;
    expect(after.amountCents, 700);
    expect(after.syncStatus, isNot(SyncStatus.synced));

    // With the current updatedAt the CAS hits and the row settles.
    await db.markTransactionSynced(id, after.updatedAt);
    expect((await db.getTransaction(id))!.syncStatus, SyncStatus.synced);
  });

  test('hasPendingRows reflects unsynced work across tables', () async {
    // A fresh DB is seeded with pendingCreate defaults.
    expect(await db.hasPendingRows(), isTrue);

    // Mark everything synced → nothing pending.
    for (final c in await db.pendingCategories()) {
      await db.markCategorySynced(c.id, c.updatedAt);
    }
    for (final a in await db.pendingAccounts()) {
      await db.markAccountSynced(a.id, a.updatedAt);
    }
    expect(await db.hasPendingRows(), isFalse);

    // A new transaction re-raises the flag.
    final repo = TransactionRepository(db);
    await repo.save(amountCents: 100, occurredAt: DateTime(2026, 6, 1));
    expect(await db.hasPendingRows(), isTrue);
  });

  test('slipAssetExists / slipRefExists are point lookups', () async {
    expect(await db.slipAssetExists('asset-1'), isFalse);
    expect(await db.slipRefExists('REF123'), isFalse);
    await db.upsertSlip(
      SlipsCompanion.insert(
        id: 's1',
        source: SlipSource.ocr,
        createdAt: 0,
        updatedAt: 0,
        assetId: const Value('asset-1'),
        transRef: const Value('REF123'),
      ),
    );
    expect(await db.slipAssetExists('asset-1'), isTrue);
    expect(await db.slipRefExists('REF123'), isTrue);
    expect(await db.slipAssetExists('asset-2'), isFalse);
  });
}
