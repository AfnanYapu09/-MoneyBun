import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/features/slip/data/slip_extractor.dart';

void main() {
  group('SlipExtractor', () {
    test('picks the largest amount with 2 decimals', () {
      const text = 'Fee 0.00\nAmount 1,234.56 THB\nBalance 20.00';
      final r = SlipExtractor.extract(text);
      expect(r.amountCents, 123456);
    });

    test('reads a plain digit run in full (OCR dropped the comma)', () {
      const text = 'Amount 1234.56 THB';
      final r = SlipExtractor.extract(text);
      expect(r.amountCents, 123456);
    });

    test('does not read a truncated slice of a longer decimal', () {
      const text = 'Meter 1,234.567 kWh';
      final r = SlipExtractor.extract(text);
      expect(r.amountCents, isNull);
    });

    test('reads an amount after dot leaders', () {
      const text = 'จำนวนเงิน.....100.00 บาท';
      final r = SlipExtractor.extract(text);
      expect(r.amountCents, 10000);
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

    test('rejects an impossible calendar date instead of normalising it', () {
      // Dart's DateTime would silently turn 31 Feb into 3 March; a misread
      // date must fall back to the photo's own date instead.
      expect(SlipExtractor.extract('31/02/2569 10:00').occurredAt, isNull);
      expect(SlipExtractor.extract('31/04/2568').occurredAt, isNull);
    });

    test('rejects an impossible time of day', () {
      expect(SlipExtractor.extract('15/06/2568 27:99').occurredAt, isNull);
    });

    test('extracts an alphanumeric reference', () {
      const text = 'Ref: AB1234567890XY done';
      final r = SlipExtractor.extract(text);
      expect(r.transRef, 'AB1234567890XY');
    });

    test('a masked payee id cannot steal the reference slot', () {
      // The masked card ("XXXXXXXXXXXX1234") appears ABOVE the real ref and
      // matches the alphanumeric shape — but it repeats on every slip to the
      // same payee, so using it as the dedup key silently drops later slips.
      const text = 'To: XXXXXXXXXXXX1234\nRef: AB1234567890XY';
      expect(SlipExtractor.extract(text).transRef, 'AB1234567890XY');
    });

    test('digits inside a masked account are not the numeric fallback ref', () {
      // No real ref on the slip; the digit run belongs to a masked account
      // fragment and must not become a (colliding) reference.
      const text = 'บัญชี XXX123456789012\nจำนวนเงิน 100.00';
      expect(SlipExtractor.extract(text).transRef, isNull);
    });

    test('a SHORT masked payee id (only 2 X\'s) still cannot steal the ref',
        () {
      // Some masks reveal more digits than others; the filter must not
      // require a specific run length to catch this.
      const text = 'To: XX345678901234\nRef: AB1234567890XY';
      expect(SlipExtractor.extract(text).transRef, 'AB1234567890XY');
    });

    test('confidence rises with more signals', () {
      final low = SlipExtractor.extract('nothing useful here');
      final high = SlipExtractor.extract(
        'KBANK 1,000.00 15/06/2025 AB1234567890',
      );
      expect(high.confidence, greaterThan(low.confidence));
    });
  });

  group('SlipExtractor co-pay slips (เป๋าตัง ไทยช่วยไทย / คนละครึ่ง)', () {
    test('reads the paid amount, not the gross, from a whole-baht slip', () {
      // ไทยช่วยไทยพลัส 60/40: goods 210, subsidy -126, paid 84 — all printed
      // without decimals. The recorded amount must be the 84 actually paid.
      const text = 'ไทยช่วยไทย พลัส\n'
          '60/40\n'
          'ทำรายการสำเร็จ\n'
          'be4e74d3f43f4bd590d48ccbb883\n'
          '3 ก.ค. 2569 21:54 น.\n'
          'G-Wallet ID: **** ******* 2993\n'
          '210 บาท\n'
          '-126 บาท\n'
          '84 บาท';
      final r = SlipExtractor.extract(text);
      expect(r.amountCents, 8400);
      expect(r.transRef, 'BE4E74D3F43F4BD590D48CCBB883');
    });

    test('noise integers (years, wallet IDs) cannot fake a co-pay match', () {
      // 2569 (BE year), 2993 (masked wallet tail) and 3 (day) are candidates
      // too, but no gross − subsidy = net triple exists among them.
      const text = '3 ก.ค. 2569\n**** 2993\n210 บาท\n-126 บาท\n84 บาท';
      expect(SlipExtractor.extract(text).amountCents, 8400);
    });

    test('resolves a 2-decimal co-pay slip to the paid amount', () {
      const text = 'รวม 1,000.00\nส่วนลด -50.00\nยอดชำระ 950.00';
      expect(SlipExtractor.extract(text).amountCents, 95000);
    });

    test('whole-baht figures without a subsidy line stay untrusted', () {
      // No minus anywhere: bare integers are too noisy to pick from directly.
      const text = '210 บาท\n84 บาท\n2569';
      expect(SlipExtractor.extract(text).amountCents, isNull);
    });

    test('unconfirmed subtraction falls back to the largest decimal', () {
      // A discount with no printed net that matches: keep the old behaviour.
      const text = 'ส่วนลด -500.00\nได้รับ 300.00';
      expect(SlipExtractor.extract(text).amountCents, 30000);
    });

    test('a lone negative decimal is a debit notation, not a subsidy', () {
      const text = 'จำนวนเงิน -500.00 บาท';
      expect(SlipExtractor.extract(text).amountCents, 50000);
    });

    test('times, dates and "60/40" fractions are never amount candidates', () {
      const text = '60/40\n21:54\n15/06/2569\n-30 บาท\n90 บาท\n60 บาท';
      // 90 − 30 = 60: a genuine triple among the บาท lines; the 60 in "60/40"
      // and the date/time fragments must not have contributed candidates.
      expect(SlipExtractor.extract(text).amountCents, 6000);
    });
  });
}
