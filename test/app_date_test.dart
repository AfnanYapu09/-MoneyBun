import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/utils/app_date.dart';

void main() {
  group('AppDate', () {
    test('startOfMonth / endOfMonth bound the month', () {
      final d = DateTime(2026, 6, 17, 13, 30);
      expect(AppDate.startOfMonth(d), DateTime(2026, 6));
      final end = AppDate.endOfMonth(d);
      expect(end.month, 6);
      expect(end.day, 30);
    });

    test('normalizeYear strips the Buddhist era only when present', () {
      expect(AppDate.normalizeYear(2569), 2026);
      expect(AppDate.normalizeYear(2026), 2026);
    });

    test('isSameDay ignores time', () {
      expect(
        AppDate.isSameDay(DateTime(2026, 6, 17, 1), DateTime(2026, 6, 17, 23)),
        isTrue,
      );
      expect(
        AppDate.isSameDay(DateTime(2026, 6, 17), DateTime(2026, 6, 18)),
        isFalse,
      );
    });

    test('startOfWeek snaps back to Sunday', () {
      // 2026-06-17 is a Wednesday; its week starts Sunday 2026-06-14.
      expect(
        AppDate.startOfWeek(DateTime(2026, 6, 17, 13)),
        DateTime(2026, 6, 14),
      );
      // A Sunday is its own week start.
      expect(
        AppDate.startOfWeek(DateTime(2026, 6, 14, 23)),
        DateTime(2026, 6, 14),
      );
    });

    test('endOfWeek is the following Saturday end-of-day', () {
      final end = AppDate.endOfWeek(DateTime(2026, 6, 17));
      expect(end.year, 2026);
      expect(end.month, 6);
      expect(end.day, 20); // Saturday
      expect(end.hour, 23);
    });

    test('addWeeks shifts by 7-day steps', () {
      expect(AppDate.addWeeks(DateTime(2026, 6, 14), 2), DateTime(2026, 6, 28));
      expect(AppDate.addWeeks(DateTime(2026, 6, 14), -1), DateTime(2026, 6, 7));
    });

    test('startOfYear / endOfYear bound the year', () {
      expect(AppDate.startOfYear(DateTime(2026, 6, 17)), DateTime(2026));
      final end = AppDate.endOfYear(DateTime(2026, 3));
      expect(end.year, 2026);
      expect(end.month, 12);
      expect(end.day, 31);
    });

    test('daysInYear counts leap years', () {
      expect(AppDate.daysInYear(2026), 365);
      expect(AppDate.daysInYear(2024), 366);
    });

    test('daysInMonth handles month lengths', () {
      expect(AppDate.daysInMonth(DateTime(2026, 6)), 30);
      expect(AppDate.daysInMonth(DateTime(2026, 2)), 28);
      expect(AppDate.daysInMonth(DateTime(2024, 2)), 29); // leap year
    });

    test('formatWeekRange collapses a shared month (en)', () {
      expect(
        AppDate.formatWeekRange(DateTime(2026, 6, 14), locale: 'en'),
        '14–20 Jun 2026',
      );
    });

    test('formatWeekRange spans two months (en)', () {
      // Week of Sunday 2026-06-28 → Saturday 2026-07-04.
      expect(
        AppDate.formatWeekRange(DateTime(2026, 6, 28), locale: 'en'),
        '28 Jun–4 Jul 2026',
      );
    });

    test('formatWeekRange labels each side of a New Year week (en)', () {
      // Week of Sunday 2026-12-27 → Saturday 2027-01-02: December must not be
      // labelled with January's year.
      expect(
        AppDate.formatWeekRange(DateTime(2026, 12, 27), locale: 'en'),
        '27 Dec 2026–2 Jan 2027',
      );
    });

    test('daysBetween counts whole calendar days regardless of time', () {
      expect(
        AppDate.daysBetween(DateTime(2026, 6, 14, 23), DateTime(2026, 6, 15)),
        1,
      );
      expect(
        AppDate.daysBetween(DateTime(2026, 6, 15), DateTime(2026, 6, 14)),
        -1,
      );
      expect(
        AppDate.daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
        1,
      );
    });

    test('addMonths / addYears pin end-of-month overflow behaviour', () {
      // Dart-normalised overflow (31 Jan + 1 month → 3 Mar) — pinned so a
      // future change here is a conscious decision, not an accident.
      expect(AppDate.addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 3, 3));
      expect(AppDate.addMonths(DateTime(2026, 3, 31), 1), DateTime(2026, 5, 1));
      expect(AppDate.addYears(DateTime(2024, 2, 29), 1), DateTime(2025, 3, 1));
    });
  });
}
