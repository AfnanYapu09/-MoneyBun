import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/utils/balances.dart';
import 'package:moneybun/data/local/database.dart';
import 'package:moneybun/data/repositories/account_repository.dart';
import 'package:moneybun/data/repositories/transaction_repository.dart';
import 'package:moneybun/domain/enums/enums.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository txns;
  late AccountRepository accounts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    txns = TransactionRepository(db);
    accounts = AccountRepository(db);
  });

  tearDown(() async => db.close());

  test('seeds default categories and accounts on first run', () async {
    final cats = await db.getCategories();
    final accs = await db.getAccounts();
    expect(cats, isNotEmpty);
    expect(accs.any((a) => a.id == 'sys_cash'), isTrue);
    expect(accs.any((a) => a.id == 'sys_truemoney'), isTrue);
  });

  test('income, expense and transfer move balances correctly', () async {
    final cash = await accounts.save(name: 'Cash', type: AccountType.cash);
    final bank = await accounts.save(name: 'Bank', type: AccountType.bank);

    await txns.save(
      type: TxnType.income,
      amountCents: 100000,
      accountId: cash,
      categoryId: 'sys_salary',
      occurredAt: DateTime.now(),
    );
    await txns.save(
      type: TxnType.expense,
      amountCents: 25000,
      accountId: cash,
      categoryId: 'sys_food',
      occurredAt: DateTime.now(),
    );
    await txns.save(
      type: TxnType.transfer,
      amountCents: 30000,
      accountId: cash,
      toAccountId: bank,
      occurredAt: DateTime.now(),
    );

    final balances = computeBalances(
      await db.getAccounts(),
      await db.getActiveTransactions(),
    );

    expect(balances[cash], 45000); // +100000 -25000 -30000
    expect(balances[bank], 30000);
  });

  test('soft delete removes a transaction from active queries', () async {
    final id = await txns.save(
      type: TxnType.expense,
      amountCents: 5000,
      accountId: 'sys_cash',
      categoryId: 'sys_food',
      occurredAt: DateTime.now(),
    );
    expect(await db.getActiveTransactions(), hasLength(1));
    await txns.delete(id);
    expect(await db.getActiveTransactions(), isEmpty);
  });

  test('editing a transaction updates it in place (no duplicate)', () async {
    final id = await txns.save(
      type: TxnType.expense,
      amountCents: 5000,
      accountId: 'sys_cash',
      categoryId: 'sys_food',
      occurredAt: DateTime.now(),
    );
    await txns.save(
      id: id,
      type: TxnType.expense,
      amountCents: 7000,
      accountId: 'sys_cash',
      categoryId: 'sys_food',
      occurredAt: DateTime.now(),
    );
    expect(await db.getActiveTransactions(), hasLength(1));
    final updated = await db.getTransaction(id);
    expect(updated!.amountCents, 7000);
  });
}
