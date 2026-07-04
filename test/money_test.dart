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

    test('rejects exponent notation and other double.parse-isms', () {
      expect(Money.parseToCents('1e5'), isNull);
      expect(Money.parseToCents('1.2e3'), isNull);
      expect(Money.parseToCents('Infinity'), isNull);
      expect(Money.parseToCents('NaN'), isNull);
      expect(Money.parseToCents('0x10'), isNull);
    });

    test('caps absurdly large amounts', () {
      expect(Money.parseToCents('999999999'), 99999999900);
      expect(Money.parseToCents('99999999999'), isNull);
    });
  });

  group('Money.compact', () {
    test('drops .00 for whole amounts, keeps satang otherwise', () {
      expect(Money.compact(2000100, symbol: false), '20,001');
      expect(Money.compact(84550, symbol: false), '845.50');
    });

    test('formats negatives with the sign before the symbol', () {
      expect(Money.compact(-50000, symbol: false), '-500');
      expect(Money.compact(-50000), '-฿500');
      expect(Money.compact(-84550, symbol: false), '-845.50');
    });

    test('zero stays unsigned', () {
      expect(Money.compact(0, symbol: false), '0');
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
