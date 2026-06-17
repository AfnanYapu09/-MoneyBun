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
  });
}
