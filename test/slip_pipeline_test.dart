import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/domain/enums/enums.dart';
import 'package:moneybun/features/slip/data/slip_extractor.dart';
import 'package:moneybun/features/slip/data/slip_party_extractor.dart';
import 'package:moneybun/features/slip/data/slip_pipeline.dart';
import 'package:moneybun/features/slip/data/tlv_parser.dart';

void main() {
  group('SlipPipeline.combine', () {
    test('prefers QR bank/ref and boosts confidence when refs agree', () {
      const qr = SlipQrData(
        crcValid: true,
        bankCode: '004',
        transRef: 'AB1234567890',
      );
      const ext = SlipExtraction(
        amountCents: 5000,
        transRef: 'AB1234567890',
        confidence: 0.6,
      );
      final slip = SlipPipeline.combine(
        qr: qr,
        extraction: ext,
        imagePath: '/tmp/slip.jpg',
        qrPayload: 'PAYLOAD',
      );

      expect(slip.bankCode, '004');
      expect(slip.transRef, 'AB1234567890');
      expect(slip.amountCents, 5000);
      expect(slip.source, SlipSource.ocr);
      // 0.6 + 0.2 (ref agreement) + 0.1 (crc valid).
      expect(slip.confidence, greaterThan(0.6));
      expect(slip.isHighConfidence, isTrue);
    });

    test('falls back to qrOnly when OCR found no amount', () {
      const qr = SlipQrData(crcValid: true, bankCode: '014');
      const ext = SlipExtraction(confidence: 0.2);
      final slip = SlipPipeline.combine(qr: qr, extraction: ext);
      expect(slip.source, SlipSource.qrOnly);
      expect(slip.bankCode, '014');
    });

    test('uses OCR signals when there is no QR at all', () {
      const ext = SlipExtraction(
        amountCents: 12000,
        bankCode: '014',
        confidence: 0.5,
      );
      final slip = SlipPipeline.combine(extraction: ext);
      expect(slip.source, SlipSource.ocr);
      expect(slip.amountCents, 12000);
      expect(slip.confidence, 0.5);
    });

    test('maps party names + Latin-detected banks and bumps confidence', () {
      const qr = SlipQrData(crcValid: true, bankCode: '004');
      const ext = SlipExtraction(amountCents: 5000, confidence: 0.6);
      const parties = SlipParties(
        senderName: 'นาย สมชาย ใจดี',
        receiverName: 'นางสาว สมหญิง รักดี',
      );
      final slip = SlipPipeline.combine(
        qr: qr,
        extraction: ext,
        parties: parties,
        latinBankCodes: ['004', '014'],
      );
      expect(slip.senderName, 'นาย สมชาย ใจดี');
      expect(slip.receiverName, 'นางสาว สมหญิง รักดี');
      expect(slip.senderBank, '004'); // from QR
      expect(slip.receiverBank, '014'); // Latin-detected other bank
      // 0.6 + 0.1 (crc) + 0.1 (sender) + 0.05 (receiver) + 0.05 (recv bank).
      expect(slip.confidence, closeTo(0.9, 1e-9));
    });

    test('receiver bank is the Latin bank that differs from the sender', () {
      const qr = SlipQrData(crcValid: true, bankCode: '004');
      const ext = SlipExtraction(amountCents: 5000, confidence: 0.6);
      // Only the sender's own bank is visible in Latin → no receiver bank.
      final slip = SlipPipeline.combine(
        qr: qr,
        extraction: ext,
        latinBankCodes: ['004'],
      );
      expect(slip.senderBank, '004');
      expect(slip.receiverBank, isNull);
    });
  });
}
