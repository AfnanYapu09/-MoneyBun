import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/features/plan/domain/quota_period.dart';

void main() {
  group('anchorFor', () {
    test('is local midnight after the signup day', () {
      expect(
        QuotaPeriod.anchorFor(DateTime(2026, 7, 13, 15, 42)),
        DateTime(2026, 7, 14),
      );
      expect(
        QuotaPeriod.anchorFor(DateTime(2026, 7, 13, 23, 59, 59)),
        DateTime(2026, 7, 14),
      );
    });

    test('signup on the last day of a month anchors on the 1st of the next',
        () {
      expect(
          QuotaPeriod.anchorFor(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
      expect(
          QuotaPeriod.anchorFor(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    });
  });

  group('periodStart (month-end clamping)', () {
    test("owner's example: signup 13/7 → boundaries 14/7, 14/8, 14/9", () {
      final anchor = QuotaPeriod.anchorFor(DateTime(2026, 7, 13));
      expect(anchor, DateTime(2026, 7, 14));
      expect(QuotaPeriod.periodStart(anchor, 0), DateTime(2026, 7, 14));
      expect(QuotaPeriod.periodStart(anchor, 1), DateTime(2026, 8, 14));
      expect(QuotaPeriod.periodStart(anchor, 2), DateTime(2026, 9, 14));
    });

    test('anchor on the 31st clamps to short months without compounding', () {
      final anchor = DateTime(2026, 1, 31); // signup 30/1
      expect(QuotaPeriod.periodStart(anchor, 1), DateTime(2026, 2, 28));
      expect(QuotaPeriod.periodStart(anchor, 2), DateTime(2026, 3, 31));
      expect(QuotaPeriod.periodStart(anchor, 3), DateTime(2026, 4, 30));
      expect(QuotaPeriod.periodStart(anchor, 4), DateTime(2026, 5, 31));
    });

    test('leap year: 31/1 clamps to 29/2', () {
      expect(
        QuotaPeriod.periodStart(DateTime(2028, 1, 31), 1),
        DateTime(2028, 2, 29),
      );
    });

    test('crosses year boundaries', () {
      expect(
        QuotaPeriod.periodStart(DateTime(2026, 11, 15), 3),
        DateTime(2027, 2, 15),
      );
    });
  });

  group('periodIndexFor', () {
    final anchor = DateTime(2026, 7, 14);

    test('a boundary instant belongs to the period it starts', () {
      expect(QuotaPeriod.periodIndexFor(anchor, DateTime(2026, 7, 14)), 0);
      expect(QuotaPeriod.periodIndexFor(anchor, DateTime(2026, 8, 14)), 1);
      expect(
        QuotaPeriod.periodIndexFor(anchor, DateTime(2026, 8, 13, 23, 59)),
        0,
      );
    });

    test('clamps to 0 before the anchor (signup-day imports)', () {
      expect(QuotaPeriod.periodIndexFor(anchor, DateTime(2026, 7, 13)), 0);
      expect(QuotaPeriod.periodIndexFor(anchor, DateTime(2020, 1, 1)), 0);
    });

    test('clamped boundary: 31/1 anchor, 28/2 starts period 1', () {
      final a = DateTime(2026, 1, 31);
      expect(QuotaPeriod.periodIndexFor(a, DateTime(2026, 2, 27)), 0);
      expect(QuotaPeriod.periodIndexFor(a, DateTime(2026, 2, 28)), 1);
      expect(QuotaPeriod.periodIndexFor(a, DateTime(2026, 3, 30)), 1);
      expect(QuotaPeriod.periodIndexFor(a, DateTime(2026, 3, 31)), 2);
    });
  });

  group('currentPeriod', () {
    test('returns [start, end) around now', () {
      final anchor = DateTime(2026, 7, 14);
      final p = QuotaPeriod.currentPeriod(anchor, DateTime(2026, 8, 20));
      expect(p.start, DateTime(2026, 8, 14));
      expect(p.end, DateTime(2026, 9, 14));
    });
  });

  group('usage', () {
    final anchor = DateTime(2026, 7, 14);
    int at(DateTime t) => t.millisecondsSinceEpoch;

    test('splits free usage per period and accumulates credit overage', () {
      // 35 slips in period 0 (5 over free), 10 in period 1.
      final created = [
        for (var i = 0; i < 35; i++) at(DateTime(2026, 7, 20, 8, i)),
        for (var i = 0; i < 10; i++) at(DateTime(2026, 8, 20, 8, i)),
      ];
      final u = QuotaPeriod.usage(
        anchor: anchor,
        createdAtsMs: created,
        now: DateTime(2026, 8, 25),
      );
      expect(u.freeUsedThisPeriod, 10);
      expect(u.creditsUsed, 5);
    });

    test('unused free never carries over: a light month refunds nothing', () {
      // 5 slips in period 0, 40 in period 1 → overage 10, not 10 - 25.
      final created = [
        for (var i = 0; i < 5; i++) at(DateTime(2026, 7, 20, 8, i)),
        for (var i = 0; i < 40; i++) at(DateTime(2026, 8, 20, 8, i)),
      ];
      final u = QuotaPeriod.usage(
        anchor: anchor,
        createdAtsMs: created,
        now: DateTime(2026, 8, 25),
      );
      expect(u.freeUsedThisPeriod, 40);
      expect(u.creditsUsed, 10);
    });

    test('empty usage', () {
      final u = QuotaPeriod.usage(
        anchor: anchor,
        createdAtsMs: const [],
        now: DateTime(2026, 7, 20),
      );
      expect(u.freeUsedThisPeriod, 0);
      expect(u.creditsUsed, 0);
    });
  });

  group('ultraExemptEndMs', () {
    test('is midnight after the inclusive expiry day', () {
      expect(
        QuotaPeriod.ultraExemptEndMs('2026-08-13'),
        DateTime(2026, 8, 14).millisecondsSinceEpoch,
      );
    });

    test('empty or malformed → 0 (nothing exempt)', () {
      expect(QuotaPeriod.ultraExemptEndMs(''), 0);
      expect(QuotaPeriod.ultraExemptEndMs('not-a-date'), 0);
      expect(QuotaPeriod.ultraExemptEndMs('2026-08'), 0);
    });
  });
}
