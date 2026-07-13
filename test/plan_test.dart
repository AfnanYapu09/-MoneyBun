import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/data/local/database.dart';
import 'package:moneybun/domain/enums/enums.dart';
import 'package:moneybun/features/plan/data/referral_service.dart';
import 'package:moneybun/features/plan/domain/plan.dart';

void main() {
  group('Plan', () {
    final now = DateTime(2026, 7, 13);

    test('monthKey/dayKey format with zero padding', () {
      expect(Plan.monthKey(now), '2026-07');
      expect(Plan.monthKey(DateTime(2026, 12, 1)), '2026-12');
      expect(Plan.dayKey(now), '2026-07-13');
    });

    test('pro only for the matching month, free otherwise', () {
      expect(
        Plan.resolve(uid: '', proMonth: '2026-07', ultraUntil: '', now: now)
            .isPro,
        isTrue,
      );
      expect(
        Plan.resolve(uid: '', proMonth: '2026-06', ultraUntil: '', now: now)
            .isFree,
        isTrue,
      );
      expect(
        Plan.resolve(uid: '', proMonth: '', ultraUntil: '', now: now).isFree,
        isTrue,
      );
    });

    test('paid ultra lasts through its expiry date and outranks pro', () {
      expect(
        Plan.resolve(uid: '', proMonth: '', ultraUntil: '2026-07-13', now: now)
            .isUltra,
        isTrue, // inclusive on the expiry day
      );
      expect(
        Plan.resolve(
                uid: '',
                proMonth: '2026-07',
                ultraUntil: '2026-08-31',
                now: now)
            .isUltra,
        isTrue, // ultra wins over same-month pro
      );
      expect(
        Plan.resolve(uid: '', proMonth: '', ultraUntil: '2026-07-12', now: now)
            .isFree,
        isTrue, // expired yesterday
      );
    });

    test('a developer uid is always ultra regardless of stored plan', () {
      const devUid = 'Y3Q8o9welfbLLCMr0RdvvDLkaZw1';
      expect(
        Plan.resolve(uid: devUid, proMonth: '', ultraUntil: '', now: now)
            .isUltra,
        isTrue, // no plan set at all — still ultra
      );
      expect(
        Plan.resolve(
          uid: devUid,
          proMonth: '2020-01', // a stale/expired-looking pro month
          ultraUntil: '2020-01-01', // and an expired ultraUntil
          now: now,
        ).isUltra,
        isTrue, // dev bypass wins over both, not just "nothing set"
      );
    });

    test('a non-developer uid is unaffected by the bypass', () {
      expect(
        Plan.resolve(
                uid: 'someOtherUser', proMonth: '', ultraUntil: '', now: now)
            .isFree,
        isTrue,
      );
    });

    test('scan limits: 30 free / 300 pro / unlimited ultra', () {
      expect(Plan.free.scanLimit, 30);
      expect(Plan.pro.scanLimit, 300);
      expect(Plan.ultra.scanLimit, isNull);
    });

    test('free locks export and recurring; pro/ultra unlock them', () {
      expect(Plan.free.canExport, isFalse);
      expect(Plan.free.canUseRecurring, isFalse);
      expect(Plan.pro.canExport, isTrue);
      expect(Plan.pro.canUseRecurring, isTrue);
      expect(Plan.ultra.canExport, isTrue);
      expect(Plan.ultra.canUseRecurring, isTrue);
    });
  });

  group('ReferralService.codeForUid', () {
    test('is deterministic, 6 chars, and avoids look-alike characters', () {
      final a = ReferralService.codeForUid('someUid123');
      expect(a, ReferralService.codeForUid('someUid123'));
      expect(a.length, 6);
      expect(RegExp(r'^[A-HJ-KM-NP-Z2-9]+$').hasMatch(a), isTrue,
          reason: 'no 0/O/1/I/L in $a');
    });

    test('differs across uids and collision attempts', () {
      expect(
        ReferralService.codeForUid('uidA'),
        isNot(ReferralService.codeForUid('uidB')),
      );
      expect(
        ReferralService.codeForUid('uidA'),
        isNot(ReferralService.codeForUid('uidA', attempt: 1)),
      );
    });
  });

  group('countSlipsCreatedBetween (monthly scan quota)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> insertSlip(String id, int createdAt, {bool deleted = false}) {
      return db.into(db.slips).insert(SlipsCompanion.insert(
            id: id,
            source: SlipSource.qrOnly,
            createdAt: createdAt,
            updatedAt: createdAt,
            deleted: Value(deleted),
          ));
    }

    test('counts only non-deleted slips inside the window', () async {
      final julStart = DateTime(2026, 7).millisecondsSinceEpoch;
      final augStart = DateTime(2026, 8).millisecondsSinceEpoch;
      await insertSlip('in-1', julStart + 1000);
      await insertSlip('in-2', augStart - 1);
      await insertSlip('deleted', julStart + 5000, deleted: true);
      await insertSlip('before', julStart - 1);
      await insertSlip('after', augStart);

      expect(await db.countSlipsCreatedBetween(julStart, augStart), 2);
    });
  });
}
