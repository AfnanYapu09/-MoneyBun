import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/constants/bank_codes.dart';

void main() {
  group('BankCodes.byCode', () {
    test('resolves a known 3-digit code to its bank', () {
      expect(BankCodes.byCode('004')?.nameTh, 'ธนาคารกสิกรไทย');
      expect(BankCodes.byCode('014')?.shortName, 'SCB');
    });

    test('resolves the TrueMoney wallet code', () {
      expect(BankCodes.byCode(BankCodes.trueMoneyCode)?.shortName, 'TrueMoney');
    });

    test('returns null for an unknown or null code', () {
      expect(BankCodes.byCode('999'), isNull);
      expect(BankCodes.byCode(null), isNull);
    });
  });
}
