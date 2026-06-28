import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/utils/app_date.dart';
import 'package:moneybun/core/utils/date_period.dart';

void main() {
  group('DatePeriod', () {
    test('month period spans the whole calendar month', () {
      final p = DatePeriod.month(DateTime(2026, 6, 17, 9));
      expect(p.isMonth, isTrue);
      expect(p.anchor, DateTime(2026, 6));
      expect(p.start, AppDate.toMillis(DateTime(2026, 6)));
      expect(p.end, AppDate.toMillis(AppDate.endOfMonth(DateTime(2026, 6))));
      expect(p.windowDays, 30);
    });

    test('week period snaps to Sunday and spans seven days', () {
      final p = DatePeriod.week(DateTime(2026, 6, 17)); // Wednesday
      expect(p.isWeek, isTrue);
      expect(p.anchor, DateTime(2026, 6, 14)); // Sunday
      expect(p.start, AppDate.toMillis(DateTime(2026, 6, 14)));
      expect(p.end, AppDate.toMillis(AppDate.endOfWeek(DateTime(2026, 6, 14))));
    });

    test('monthAnchor reports the containing month in week mode', () {
      final p = DatePeriod.week(DateTime(2026, 6, 28)); // crosses into July
      expect(p.monthAnchor, DateTime(2026, 6));
    });

    test('year period spans the whole year', () {
      final p = DatePeriod.year(DateTime(2026, 6, 17));
      expect(p.isYear, isTrue);
      expect(p.anchor, DateTime(2026));
      expect(p.start, AppDate.toMillis(DateTime(2026)));
      expect(p.end, AppDate.toMillis(AppDate.endOfYear(DateTime(2026))));
      expect(p.windowDays, 365); // 2026 is not a leap year
    });

    test('next / previous step by the active unit', () {
      final month = DatePeriod.month(DateTime(2026, 6));
      expect(month.next().anchor, DateTime(2026, 7));
      expect(month.previous().anchor, DateTime(2026, 5));

      final week = DatePeriod.week(DateTime(2026, 6, 14));
      expect(week.next().anchor, DateTime(2026, 6, 21));
      expect(week.previous().anchor, DateTime(2026, 6, 7));

      final year = DatePeriod.year(DateTime(2026));
      expect(year.next().anchor, DateTime(2027));
      expect(year.previous().anchor, DateTime(2025));
    });

    test('value equality by mode + anchor', () {
      expect(DatePeriod.month(DateTime(2026, 6, 1)),
          DatePeriod.month(DateTime(2026, 6, 20)));
      expect(DatePeriod.month(DateTime(2026, 6)) ==
          DatePeriod.week(DateTime(2026, 6, 14)),
          isFalse);
    });
  });
}
