import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/utils/calculator.dart';

// Operator glyphs the keypad uses, spelled out so the test expressions read
// like what the user sees on screen.
const add = '+';
const sub = '−'; // U+2212 minus sign
const mul = '×'; // U+00D7
const div = '÷'; // U+00F7

void main() {
  group('Calculator.evaluate', () {
    test('evaluates a single number', () {
      expect(Calculator.evaluate('100'), 100);
      expect(Calculator.evaluate('0'), 0);
      expect(Calculator.evaluate('12.5'), 12.5);
    });

    test('respects × ÷ over + − precedence', () {
      expect(Calculator.evaluate('100${mul}2'), 200);
      expect(Calculator.evaluate('10${add}2${mul}3'), 16);
      expect(Calculator.evaluate('20${sub}6${div}2'), 17);
    });

    test('ignores a trailing operator or dot', () {
      expect(Calculator.evaluate('100$mul'), 100);
      expect(Calculator.evaluate('100.'), 100);
      expect(Calculator.evaluate(''), isNull);
    });

    test('returns null on divide by zero', () {
      expect(Calculator.evaluate('5${div}0'), isNull);
    });
  });

  group('Calculator.input (key handling)', () {
    test('builds a multiplication expression', () {
      var e = '';
      for (final k in ['1', '0', '0', mul, '2']) {
        e = Calculator.input(e, k);
      }
      expect(e, '100${mul}2');
      expect(Calculator.evaluate(e), 200);
    });

    test('collapses a lone leading zero', () {
      expect(Calculator.input('0', '5'), '5');
      expect(Calculator.input('0', '0'), '0');
    });

    test('allows only one decimal point per number', () {
      expect(Calculator.input('1.5', '.'), '1.5');
      expect(Calculator.input('', '.'), '0.');
    });

    test('swaps a pending operator instead of stacking', () {
      expect(Calculator.input('5$add', mul), '5$mul');
    });

    test('back and clear edit the expression', () {
      expect(Calculator.input('123', 'back'), '12');
      expect(Calculator.input('123', 'clear'), '');
    });
  });

  group('Calculator percent', () {
    test('a bare percent is value / 100', () {
      final e = Calculator.input('50', '%');
      expect(Calculator.evaluate(e), 0.5);
    });

    test('percent after + is a share of the left operand (VAT 7%)', () {
      final e = Calculator.input('200${add}7', '%');
      expect(Calculator.evaluate(e), 214);
    });

    test('percent after × is just value / 100', () {
      final e = Calculator.input('200${mul}10', '%');
      expect(Calculator.evaluate(e), 20);
    });
  });

  group('Calculator.formatResult', () {
    test('drops the decimal part for whole numbers', () {
      expect(Calculator.formatResult(200), '200');
      expect(Calculator.formatResult(200.5), '200.5');
      expect(Calculator.formatResult(200.555), '200.56');
    });
  });
}
