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

    test('pro while credits remain, free at zero', () {
      expect(
        Plan.resolve(uid: '', ultraUntil: '', creditBalance: 1, now: now).isPro,
        isTrue,
      );
      expect(
        Plan.resolve(uid: '', ultraUntil: '', creditBalance: 300, now: now)
            .isPro,
        isTrue,
      );
      expect(
        Plan.resolve(uid: '', ultraUntil: '', creditBalance: 0, now: now)
            .isFree,
        isTrue,
      );
    });

    test('paid ultra lasts through its expiry date and outranks credits', () {
      expect(
        Plan.resolve(
                uid: '', ultraUntil: '2026-07-13', creditBalance: 0, now: now)
            .isUltra,
        isTrue, // inclusive on the expiry day
      );
      expect(
        Plan.resolve(
                uid: '', ultraUntil: '2026-08-31', creditBalance: 300, now: now)
            .isUltra,
        isTrue, // ultra wins over a positive balance
      );
      expect(
        Plan.resolve(
                uid: '', ultraUntil: '2026-07-12', creditBalance: 0, now: now)
            .isFree,
        isTrue, // expired yesterday
      );
    });

    test('a developer uid is always ultra regardless of stored plan', () {
      const devUid = 'Y3Q8o9welfbLLCMr0RdvvDLkaZw1';
      expect(
        Plan.resolve(uid: devUid, ultraUntil: '', creditBalance: 0, now: now)
            .isUltra,
        isTrue, // no plan at all — still ultra
      );
      expect(
        Plan.resolve(
          uid: devUid,
          ultraUntil: '2020-01-01', // an expired ultraUntil
          creditBalance: 0,
          now: now,
        ).isUltra,
        isTrue, // dev bypass wins, not just "nothing set"
      );
    });

    test('a non-developer uid is unaffected by the bypass', () {
      expect(
        Plan.resolve(
                uid: 'someOtherUser',
                ultraUntil: '',
                creditBalance: 0,
                now: now)
            .isFree,
        isTrue,
      );
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

  group('Membership', () {
    final now = DateTime(2026, 7, 20);

    Membership build({
      required int freeUsed,
      required int granted,
      required int used,
      Plan plan = Plan.free,
    }) {
      return Membership(
        plan: plan,
        freeUsed: freeUsed,
        creditsGranted: granted,
        creditsUsed: used,
        periodStart: DateTime(2026, 7, 14),
        periodResetAt: DateTime(2026, 8, 14),
        isOld: false,
        backfillCutoffMs: 0,
      );
    }

    test("owner's example: fresh free 30 + one referral = 330 scans", () {
      final m = build(freeUsed: 0, granted: 300, used: 0, plan: Plan.pro);
      expect(m.freeRemaining, 30);
      expect(m.creditBalance, 300);
      expect(m.remainingScans, 330);
    });

    test('free is consumed before credits', () {
      final m = build(freeUsed: 12, granted: 300, used: 0, plan: Plan.pro);
      expect(m.freeRemaining, 18);
      expect(m.remainingScans, 318);
    });

    test('balance and free floor at zero', () {
      final m = build(freeUsed: 45, granted: 300, used: 310);
      expect(m.freeRemaining, 0);
      expect(m.creditBalance, 0);
      expect(m.remainingScans, 0);
    });

    test('ultra is unlimited regardless of the numbers', () {
      final m = build(freeUsed: 999, granted: 0, used: 0, plan: Plan.ultra);
      expect(m.unlimited, isTrue);
      expect(m.remainingScans, greaterThan(1000000));
    });

    test('fallback is a plain calendar-month free membership', () {
      final m = Membership.fallback(now);
      expect(m.plan.isFree, isTrue);
      expect(m.periodStart, DateTime(2026, 7));
      expect(m.periodResetAt, DateTime(2026, 8));
      expect(m.backfillCutoffMs, 0);
      expect(m.isOld, isFalse);
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

  group('countableSlipCreatedTimes (credit accounting source)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> insertSlip(
      String id,
      int createdAt, {
      int? photoTakenAt,
      bool deleted = false,
    }) {
      return db.into(db.slips).insert(SlipsCompanion.insert(
            id: id,
            source: SlipSource.qrOnly,
            createdAt: createdAt,
            updatedAt: createdAt,
            photoTakenAt: Value(photoTakenAt),
            deleted: Value(deleted),
          ));
    }

    test('excludes backfill (photo before cutoff), keeps null photo times',
        () async {
      final cutoff = DateTime(2026, 7, 14).millisecondsSinceEpoch;
      final t = DateTime(2026, 7, 20).millisecondsSinceEpoch;
      await insertSlip('backfill', t, photoTakenAt: cutoff - 1);
      await insertSlip('counted-at-cutoff', t, photoTakenAt: cutoff);
      await insertSlip('counted-later', t + 1, photoTakenAt: cutoff + 999);
      await insertSlip('counted-null-photo', t + 2);
      await insertSlip('deleted', t + 3,
          photoTakenAt: cutoff + 5, deleted: true);

      final times = await db.countableSlipCreatedTimes(
        sinceMs: 0,
        backfillCutoffMs: cutoff,
        ultraExemptEndMs: 0,
      );
      expect(times, [t, t + 1, t + 2]);
    });

    test('excludes the ultra window and pre-epoch imports', () async {
      final epoch = DateTime(2026, 7, 13).millisecondsSinceEpoch;
      final ultraEnd = DateTime(2026, 8, 14).millisecondsSinceEpoch;
      await insertSlip('pre-epoch', epoch - 1);
      await insertSlip('in-ultra', ultraEnd - 1);
      await insertSlip('after-ultra', ultraEnd);

      final times = await db.countableSlipCreatedTimes(
        sinceMs: epoch,
        backfillCutoffMs: 0,
        ultraExemptEndMs: ultraEnd,
      );
      expect(times, [ultraEnd]);
    });

    test('deleting a slip refunds its usage', () async {
      final t = DateTime(2026, 7, 20).millisecondsSinceEpoch;
      await insertSlip('kept', t);
      await insertSlip('gone', t + 1, deleted: true);

      final times = await db.countableSlipCreatedTimes(
        sinceMs: 0,
        backfillCutoffMs: 0,
        ultraExemptEndMs: 0,
      );
      expect(times, [t]);
    });
  });
}
