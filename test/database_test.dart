import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/data/local/database.dart';
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
}
