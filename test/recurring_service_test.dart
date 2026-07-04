import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/data/recurring/recurring_service.dart';
import 'package:moneybun/domain/enums/enums.dart';

void main() {
  DateTime next(DateTime d, RecurFreq freq, int anchorDay) =>
      DateTime.fromMillisecondsSinceEpoch(
        RecurringService.advance(d.millisecondsSinceEpoch, freq, anchorDay),
      );

  group('RecurringService.advance monthly', () {
    test('clamps a day-31 anchor to short months, then restores it', () {
      final jan = DateTime(2026, 1, 31, 9, 30);
      final feb = next(jan, RecurFreq.monthly, 31);
      expect(feb, DateTime(2026, 2, 28, 9, 30)); // 2026 is not a leap year
      final mar = next(feb, RecurFreq.monthly, 31);
      expect(mar, DateTime(2026, 3, 31, 9, 30)); // back on the anchor day
      final apr = next(mar, RecurFreq.monthly, 31);
      expect(apr, DateTime(2026, 4, 30, 9, 30));
    });

    test('never skips a month (the old DateTime-overflow bug)', () {
      // Before the clamp, Oct 31 advanced to "Nov 31" == Dec 1: November got
      // no occurrence and the rule re-anchored to the 1st forever.
      var d = DateTime(2026, 10, 31);
      final months = <int>[];
      for (var i = 0; i < 6; i++) {
        d = next(d, RecurFreq.monthly, 31);
        months.add(d.month);
      }
      expect(months, [11, 12, 1, 2, 3, 4]);
    });

    test('day-29 anchor lands on Feb 29 in a leap year, Feb 28 otherwise', () {
      expect(
        next(DateTime(2028, 1, 29), RecurFreq.monthly, 29),
        DateTime(2028, 2, 29),
      );
      expect(
        next(DateTime(2026, 1, 29), RecurFreq.monthly, 29),
        DateTime(2026, 2, 28),
      );
    });

    test('mid-month anchors are unaffected', () {
      expect(
        next(DateTime(2026, 1, 15, 8), RecurFreq.monthly, 15),
        DateTime(2026, 2, 15, 8),
      );
    });

    test('crosses a year boundary', () {
      expect(
        next(DateTime(2026, 12, 31), RecurFreq.monthly, 31),
        DateTime(2027, 1, 31),
      );
    });
  });

  group('RecurringService.advance daily/weekly', () {
    test('daily adds one day', () {
      expect(
        next(DateTime(2026, 2, 28), RecurFreq.daily, 28),
        DateTime(2026, 3, 1),
      );
    });

    test('weekly adds seven days', () {
      expect(
        next(DateTime(2026, 6, 30), RecurFreq.weekly, 30),
        DateTime(2026, 7, 7),
      );
    });
  });
}
