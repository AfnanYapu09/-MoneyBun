import '../../../domain/entities/parsed_slip.dart';
import '../../../domain/enums/enums.dart';
import 'slip_extractor.dart';
import 'slip_ocr_service.dart';
import 'slip_qr_scanner.dart';
import 'tlv_parser.dart';

/// Orchestrates the hybrid slip read: QR scan -> TLV parse -> Latin OCR ->
/// heuristic extraction -> combined [ParsedSlip]. The optional online verify
/// step (Cloud Function) is invoked separately by the UI when the user asks for
/// it or confidence is low.
class SlipPipeline {
  SlipPipeline(this._qr, this._ocr);

  final SlipQrScanner _qr;
  final SlipOcrService _ocr;

  Future<ParsedSlip> process(String imagePath) async {
    final payload = await _qr.scanFromImage(imagePath);
    final qr = payload != null ? EmvTlvParser.parseSlip(payload) : null;
    final ocrText = await _ocr.recognizeText(imagePath);
    final extraction = SlipExtractor.extract(ocrText);
    return combine(
      imagePath: imagePath,
      qrPayload: payload,
      qr: qr,
      ocrText: ocrText,
      extraction: extraction,
    );
  }

  /// Pure combination of QR + OCR signals into a [ParsedSlip]. Extracted so it
  /// can be unit-tested without any plugins.
  static ParsedSlip combine({
    String? imagePath,
    String? qrPayload,
    SlipQrData? qr,
    String? ocrText,
    required SlipExtraction extraction,
  }) {
    final bankCode = qr?.bankCode ?? extraction.bankCode;
    final transRef = qr?.transRef ?? extraction.transRef;

    var confidence = extraction.confidence;
    // Agreement between QR ref and OCR ref is a strong signal.
    if (qr?.transRef != null &&
        extraction.transRef != null &&
        qr!.transRef == extraction.transRef) {
      confidence += 0.2;
    }
    if (qr?.crcValid == true) confidence += 0.1;
    confidence = confidence.clamp(0, 1).toDouble();

    final source = extraction.amountCents == null && qr != null
        ? SlipSource.qrOnly
        : SlipSource.ocr;

    return ParsedSlip(
      source: source,
      imagePath: imagePath,
      qrPayload: qrPayload,
      bankCode: bankCode,
      transRef: transRef,
      amountCents: extraction.amountCents,
      occurredAt: extraction.occurredAt,
      rawOcrText: ocrText,
      confidence: confidence,
    );
  }
}
