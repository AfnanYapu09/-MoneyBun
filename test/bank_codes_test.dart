import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/constants/bank_codes.dart';

void main() {
  group('BankCodes.detectFromText', () {
    test('detects a Latin token', () {
      expect(BankCodes.detectFromText('KBANK K PLUS')?.code, '004');
    });

    test('detects a Thai bank name', () {
      expect(BankCodes.detectFromText('ธนาคารไทยพาณิชย์')?.code, '014');
      final trueMoney = BankCodes.detectFromText('โอนเข้าทรูมันนี่')?.code;
      expect(trueMoney, BankCodes.trueMoneyCode);
    });

    test('distinguishes the กรุง- banks without colliding', () {
      expect(BankCodes.detectFromText('ธนาคารกรุงเทพ')?.code, '002');
      expect(BankCodes.detectFromText('ธนาคารกรุงไทย')?.code, '006');
      expect(BankCodes.detectFromText('ธนาคารกรุงศรีอยุธยา')?.code, '025');
    });

    test('returns null when no bank is mentioned', () {
      expect(BankCodes.detectFromText('จำนวน 1,000.00 บาท'), isNull);
    });
  });

  group('BankCodes.detectAllFromText', () {
    test('orders banks by where they first appear (top → bottom)', () {
      const text = 'ธนาคารกสิกรไทย\nไปยัง\nธนาคารไทยพาณิชย์';
      final banks = BankCodes.detectAllFromText(text);
      final codes = banks.map((b) => b.code).toList();
      expect(codes, ['004', '014']);
    });

    test('deduplicates a bank mentioned twice', () {
      const text = 'ธนาคารกสิกรไทย ... ธนาคารกสิกรไทย';
      final banks = BankCodes.detectAllFromText(text);
      final codes = banks.map((b) => b.code).toList();
      expect(codes, ['004']);
    });
  });
}
