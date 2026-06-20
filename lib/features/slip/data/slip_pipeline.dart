import '../../../domain/entities/parsed_slip.dart';
import '../../../domain/enums/enums.dart';
import 'slip_extractor.dart';
import 'slip_ocr_service.dart';
import 'slip_qr_scanner.dart';
import 'tlv_parser.dart';

/// Reads a slip image fully on-device for one thing only: the **amount**.
///
/// QR scan -> TLV parse (confirms it's a slip + gives a transaction ref) and
/// Latin OCR (ML Kit) -> heuristic extraction of the amount / date / ref. No
/// Thai (Tesseract) pass and no name/bank reading — those were slow and noisy,
/// so the pipeline keeps only the cheap, reliable signals.
class SlipPipeline {
  SlipPipeline(this._qr, this._ocr);

  final SlipQrScanner _qr;
  final SlipOcrService _ocr;

  Future<ParsedSlip> process(String imagePath) async {
    final payload = await _qr.scanFromImage(imagePath);
    final qr = payload != null ? EmvTlvParser.parseSlip(payload) : null;
    final latinText = await _ocr.recognizeLatin(imagePath);
    final extraction = SlipExtractor.extract(latinText);
    return combine(
      imagePath: imagePath,
      qrPayload: payload,
      qr: qr,
      ocrText: latinText,
      extraction: extraction,
    );
  }

  /// Release the reusable QR controller + ML Kit recognizer. Call once when a
  /// scan batch finishes.
  Future<void> dispose() async {
    await _qr.dispose();
    await _ocr.dispose();
  }

  /// Pure combination of QR + OCR signals into a [ParsedSlip]. Extracted so it
  /// can be unit-tested without any plugins. Only the amount (and supporting
  /// date/ref/confidence) is recovered — names and banks are never read.
  static ParsedSlip combine({
    String? imagePath,
    String? qrPayload,
    SlipQrData? qr,
    String? ocrText,
    required SlipExtraction extraction,
  }) {
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
      transRef: transRef,
      amountCents: extraction.amountCents,
      occurredAt: extraction.occurredAt,
      rawOcrText: ocrText,
      confidence: confidence,
    );
  }
}
