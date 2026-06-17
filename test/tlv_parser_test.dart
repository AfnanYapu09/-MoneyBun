import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/features/slip/data/tlv_parser.dart';

/// Encode one EMVCo TLV field: 2-char id + 2-digit length + value.
String tlv(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';

/// Append the EMVCo CRC (tag 63, len 04) to a payload body.
String withCrc(String body) {
  final base = '${body}6304';
  final crc =
      EmvTlvParser.crc16(base).toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$base$crc';
}

void main() {
  group('crc16 (CRC-16/CCITT-FALSE)', () {
    test('matches the catalogued check value for "123456789"', () {
      expect(EmvTlvParser.crc16('123456789'), 0x29B1);
    });
  });

  group('parseFields', () {
    test('splits flat TLV triplets', () {
      final fields =
          EmvTlvParser.parseFields(tlv('00', '01') + tlv('01', '004'));
      expect(fields.length, 2);
      expect(fields[0].id, '00');
      expect(fields[0].value, '01');
      expect(fields[1].id, '01');
      expect(fields[1].value, '004');
    });

    test('stops cleanly on malformed length', () {
      expect(EmvTlvParser.parseFields('00XX01'), isEmpty);
    });
  });

  group('validateCrc', () {
    test('accepts a payload with a correct trailing CRC', () {
      final payload = withCrc(tlv('00', '01') + tlv('01', '004'));
      expect(EmvTlvParser.validateCrc(payload), isTrue);
    });

    test('rejects a tampered payload', () {
      final payload = withCrc(tlv('00', '01'));
      final tampered = payload.substring(0, payload.length - 1) +
          (payload.endsWith('A') ? 'B' : 'A');
      expect(EmvTlvParser.validateCrc(tampered), isFalse);
    });
  });

  group('parseSlip', () {
    test('extracts bank code (004=KBANK) and transaction reference', () {
      final body =
          tlv('00', '01') + tlv('01', '004') + tlv('02', 'AB1234567890');
      final data = EmvTlvParser.parseSlip(withCrc(body));

      expect(data.crcValid, isTrue);
      expect(data.bankCode, '004');
      expect(data.transRef, 'AB1234567890');
    });
  });
}
