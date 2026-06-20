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
    });

    test('label on its own line, name on the next line', () {
      const text = 'ผู้โอน\nนาย เอ\nผู้รับเงิน\nนางสาว บี';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.senderName, 'นาย เอ');
      expect(p.receiverName, 'นางสาว บี');
    });

    test('sender name without an honorific, after a label', () {
      const text = 'ผู้โอน\n'
          'สมชาย ใจดี\n'
          'ธนาคารกสิกรไทย\n'
          'ไปยัง นางสาว บี\n'
          'ธนาคารไทยพาณิชย์';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.senderName, 'สมชาย ใจดี');
      expect(p.receiverName, 'นางสาว บี');
    });

    test('strips a masked account number out of the captured name', () {
      const text = 'ผู้รับเงิน นางสาว ข xxx-x-x1234-x';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.receiverName, 'นางสาว ข');
    });

    test('sender name abutting a masked account, no honorific', () {
      const text = 'จาก\nสมหญิง รักดี xxx-x-x1234-x\nธนาคารไทยพาณิชย์';
      final p = SlipPartyExtractor.extract(thaiText: text);
      expect(p.senderName, 'สมหญิง รักดี');
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
