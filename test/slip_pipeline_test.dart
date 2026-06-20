import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/domain/enums/enums.dart';
import 'package:moneybun/features/slip/data/slip_extractor.dart';
import 'package:moneybun/features/slip/data/slip_pipeline.dart';
import 'package:moneybun/features/slip/data/tlv_parser.dart';

void main() {
  group('SlipPipeline.combine', () {
    test('keeps the amount + ref and boosts confidence when refs agree', () {
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

      expect(slip.transRef, 'AB1234567890');
      expect(slip.amountCents, 5000);
      expect(slip.source, SlipSource.ocr);
      // 0.6 + 0.2 (ref agreement) + 0.1 (crc valid).
      expect(slip.confidence, greaterThan(0.6));
      expect(slip.isHighConfidence, isTrue);
    });

    test('never reads names or banks (always null)', () {
      const qr = SlipQrData(crcValid: true, bankCode: '004');
      const ext = SlipExtraction(amountCents: 5000, confidence: 0.6);
      final slip = SlipPipeline.combine(qr: qr, extraction: ext);

      expect(slip.amountCents, 5000);
      expect(slip.bankCode, isNull);
      expect(slip.senderBank, isNull);
      expect(slip.receiverBank, isNull);
      expect(slip.senderName, isNull);
      expect(slip.receiverName, isNull);
    });

    test('falls back to qrOnly when OCR found no amount', () {
      const qr = SlipQrData(crcValid: true, bankCode: '014');
      const ext = SlipExtraction(confidence: 0.2);
      final slip = SlipPipeline.combine(qr: qr, extraction: ext);
      expect(slip.source, SlipSource.qrOnly);
      expect(slip.amountCents, isNull);
    });

    test('uses OCR signals when there is no QR at all', () {
      const ext = SlipExtraction(amountCents: 12000, confidence: 0.5);
      final slip = SlipPipeline.combine(extraction: ext);
      expect(slip.source, SlipSource.ocr);
      expect(slip.amountCents, 12000);
      expect(slip.confidence, 0.5);
    });
  });
}
