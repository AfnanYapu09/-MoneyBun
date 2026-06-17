import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/utils/money.dart';

void main() {
  group('Money.parseToCents', () {
    test('parses plain and grouped numbers', () {
      expect(Money.parseToCents('1234'), 123400);
      expect(Money.parseToCents('1,234.56'), 123456);
      expect(Money.parseToCents('0.05'), 5);
      expect(Money.parseToCents('฿99.90'), 9990);
    });

    test('rejects invalid input', () {
      expect(Money.parseToCents(''), isNull);
      expect(Money.parseToCents('abc'), isNull);
      expect(Money.parseToCents('-5'), isNull);
    });
  });

  group('Money.format', () {
    test('formats cents to a baht string', () {
      expect(Money.format(123456, symbol: false), '1,234.56');
    });

    test('signs values', () {
      expect(Money.formatSigned(5000, symbol: false), '+50.00');
      expect(Money.formatSigned(-5000, symbol: false), '-50.00');
    });

    test('round-trips through edit string', () {
      expect(Money.toEditString(123456), '1234.56');
      expect(Money.parseToCents(Money.toEditString(123456)), 123456);
    });
  });
}
