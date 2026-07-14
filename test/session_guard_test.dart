import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/data/local/database.dart';
import 'package:moneybun/data/repositories/settings_repository.dart';
import 'package:moneybun/data/session_guard.dart';
import 'package:moneybun/domain/enums/enums.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late SessionGeneration gen;
  late DbOwnershipGuard guard;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
    gen = SessionGeneration();
    guard = DbOwnershipGuard(db, settings, gen);
  });
  tearDown(() => db.close());

  Future<void> addTxn(String id) => db.upsertTransaction(
        TransactionsCompanion.insert(
          id: id,
          type: TxnType.expense,
          amountCents: 100,
          accountId: 'acc_cash',
          occurredAt: 1,
          createdAt: 1,
          updatedAt: 1,
          note: const Value('residue'),
        ),
      );

  test('first sign-in claims ownership without wiping', () async {
    await addTxn('t1');
    await guard.ensure('uid-A');
    expect(await settings.dbOwnerUid(), 'uid-A');
    // Guest-era data is kept (existing behavior: trying the app before
    // signing up keeps what you recorded).
    expect(await db.getActiveTransactions(), hasLength(1));
    expect(gen.value, 0, reason: 'no wipe → no generation bump');
  });

  test('same owner signing back in keeps the data', () async {
    await guard.ensure('uid-A');
    await addTxn('t1');
    await guard.ensure('uid-A');
    expect(await db.getActiveTransactions(), hasLength(1));
    expect(gen.value, 0);
  });

  test('a different account wipes the residue and re-seeds defaults', () async {
    await guard.ensure('uid-A');
    await addTxn('t1');
    await settings.setDisplayName('เจ้าของเก่า');

    await guard.ensure('uid-B');

    expect(await settings.dbOwnerUid(), 'uid-B');
    expect(await db.getActiveTransactions(), isEmpty,
        reason: "uid-A's rows must not leak into uid-B's session");
    expect((await settings.read()).displayName, isNot('เจ้าของเก่า'));
    expect(await db.getCategories(), isNotEmpty,
        reason: 'the new account must not start bare — defaults re-seeded');
    expect(gen.value, greaterThan(0),
        reason: 'the wipe must abort in-flight work via a generation bump');
  });

  test('generation invalidates values captured before the bump', () {
    final captured = gen.value;
    expect(gen.isCurrent(captured), isTrue);
    gen.bump();
    expect(gen.isCurrent(captured), isFalse);
  });

  test('two overlapping ensure() calls for a mismatched owner wipe only once',
      () async {
    // Mirrors the app-launch race: SyncController's constructor microtask and
    // its auth-state replay can both call ensureOwnership(uid) before either
    // has written the new owner. Without in-flight dedup both would run the
    // full wipe sequence (and bump the generation) a second, redundant time,
    // aborting the first caller's still-in-flight sync.
    await guard.ensure('uid-A');
    await addTxn('t1');

    final first = guard.ensure('uid-B');
    final second = guard.ensure('uid-B');
    await Future.wait([first, second]);

    expect(await settings.dbOwnerUid(), 'uid-B');
    expect(await db.getActiveTransactions(), isEmpty);
    expect(gen.value, 1,
        reason: 'the wipe must run exactly once, not once per caller');
  });
}
