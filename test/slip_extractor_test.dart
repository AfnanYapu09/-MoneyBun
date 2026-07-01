import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/features/slip/data/slip_extractor.dart';

void main() {
  group('SlipExtractor', () {
    test('picks the largest amount with 2 decimals', () {
      const text = 'Fee 0.00\nAmount 1,234.56 THB\nBalance 20.00';
      final r = SlipExtractor.extract(text);
      expect(r.amountCents, 123456);
    });

    test('parses a Gregorian date and time', () {
      const text = 'Date 15/06/2025 14:23 ref X';
      final r = SlipExtractor.extract(text);
      expect(r.occurredAt, DateTime(2025, 6, 15, 14, 23));
    });

    test('normalises a Buddhist-era year (พ.ศ. 2568 -> 2025)', () {
      const text = '15/06/2568 09:05';
      final r = SlipExtractor.extract(text);
      expect(r.occurredAt!.year, 2025);
    });

    test('extracts an alphanumeric reference', () {
      const text = 'Ref: AB1234567890XY done';
      final r = SlipExtractor.extract(text);
      expect(r.transRef, 'AB1234567890XY');
    });

    test('confidence rises with more signals', () {
      final low = SlipExtractor.extract('nothing useful here');
      final high = SlipExtractor.extract(
        'KBANK 1,000.00 15/06/2025 AB1234567890',
      );
      expect(high.confidence, greaterThan(low.confidence));
    });
  });
}
