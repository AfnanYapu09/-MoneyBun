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
      expect(AppDate.startOfWeek(DateTime(2026, 6, 17, 13)),
          DateTime(2026, 6, 14));
      // A Sunday is its own week start.
      expect(AppDate.startOfWeek(DateTime(2026, 6, 14, 23)),
          DateTime(2026, 6, 14));
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
  });
}
