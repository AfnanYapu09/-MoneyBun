import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/features/slip/data/slip_party_extractor.dart';

void main() {
  group('SlipPartyExtractor', () {
    test('label-anchored sender/receiver on the same line', () {
      const text = 'จาก นาย สมชาย ใจดี\n'
          'ธนาคารกสิกรไทย\n'
          'ไปยัง นางสาว สมหญิง รักดี\n'
          'ธนาคารไทยพาณิชย์';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.senderName, 'นาย สมชาย ใจดี');
      expect(p.receiverName, 'นางสาว สมหญิง รักดี');
      expect(p.senderBankCode, '004'); // กสิกร
      expect(p.receiverBankCode, '014'); // ไทยพาณิชย์
    });

    test('label on its own line, name on the next line', () {
      const text = 'ผู้โอน\nนาย เอ\nผู้รับเงิน\nนางสาว บี';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.senderName, 'นาย เอ');
      expect(p.receiverName, 'นางสาว บี');
    });

    test('strips a masked account number out of the captured name', () {
      const text = 'ผู้รับเงิน นางสาว ข xxx-x-x1234-x';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.receiverName, 'นางสาว ข');
    });

    test('two-name fallback when there are no direction labels', () {
      const text = 'นาย สมชาย ใจดี\n'
          'ธนาคารกสิกรไทย\n'
          'xxx-x-x1234-x\n'
          'นางสาว สมหญิง รักดี\n'
          'ธนาคารไทยพาณิชย์\n'
          'xxx-x-x5678-x';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.senderName, 'นาย สมชาย ใจดี'); // top = sender
      expect(p.receiverName, 'นางสาว สมหญิง รักดี'); // below = receiver
      expect(p.senderBankCode, '004');
      expect(p.receiverBankCode, '014');
    });

    test('QR sender bank wins; receiver is the other bank', () {
      const text = 'จาก นาย เอ\n'
          'ธนาคารกรุงเทพ\n'
          'ไปยัง นางสาว บี\n'
          'ธนาคารไทยพาณิชย์';
      final p = SlipPartyExtractor.extract(
        thaiText: text,
        qrSenderBankCode: '002',
      );
      expect(p.senderBankCode, '002'); // from QR (authoritative)
      expect(p.receiverBankCode, '014');
    });

    test('same-bank transfer with no labels leaves receiver bank null', () {
      const text = 'นาย เอ\nธนาคารกสิกรไทย\nนางสาว บี\nธนาคารกสิกรไทย';
      final p = SlipPartyExtractor.extract(
        thaiText: text,
        qrSenderBankCode: '004',
      );
      expect(p.senderBankCode, '004');
      expect(p.receiverBankCode, isNull); // only the sender's bank is visible
    });

    test('does not treat amount/ref/header lines as names', () {
      const text = 'โอนเงินสำเร็จ\nจำนวน 1,000.00 บาท\nรหัสอ้างอิง 1234567890';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.senderName, isNull);
      expect(p.receiverName, isNull);
    });

    test('empty input yields empty parties', () {
      final p = SlipPartyExtractor.extract(thaiText: '');
      expect(p.isEmpty, isTrue);
    });
  });
}
