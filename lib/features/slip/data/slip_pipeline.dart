import '../../../domain/entities/parsed_slip.dart';
import '../../../domain/enums/enums.dart';
import 'slip_extractor.dart';
import 'slip_ocr_service.dart';
import 'slip_party_extractor.dart';
import 'slip_qr_scanner.dart';
import 'tlv_parser.dart';

/// Orchestrates the fully on-device hybrid slip read: QR scan -> TLV parse ->
/// Latin OCR (amount/date/ref) -> Thai OCR (names/banks) -> heuristic
/// extraction -> combined [ParsedSlip]. No network/cloud step is involved.
///
/// The Thai (Tesseract) pass is the expensive one, so it only runs once the
/// cheap signals (QR or a Latin amount) already say the image is a slip — this
/// keeps the gallery fallback scan from running Tesseract on ordinary photos.
class SlipPipeline {
  SlipPipeline(this._qr, this._ocr);

  final SlipQrScanner _qr;
  final SlipOcrService _ocr;

  Future<ParsedSlip> process(String imagePath) async {
    final payload = await _qr.scanFromImage(imagePath);
    final qr = payload != null ? EmvTlvParser.parseSlip(payload) : null;
    final latinText = await _ocr.recognizeLatin(imagePath);
    final extraction = SlipExtractor.extract(latinText);

    // Gate the costly Thai OCR behind the same "looks like a slip" signal the
    // importer uses, so non-slip photos never pay the Tesseract cost.
    var thaiText = '';
    SlipParties? parties;
    if (qr != null || extraction.amountCents != null) {
      thaiText = await _ocr.recognizeThai(imagePath);
      parties = SlipPartyExtractor.extract(
        thaiText: thaiText,
        qrSenderBankCode: qr?.bankCode,
      );
    }

    var rawText = latinText;
    if (thaiText.isNotEmpty) rawText = '$latinText\n[TH]\n$thaiText';
    return combine(
      imagePath: imagePath,
      qrPayload: payload,
      qr: qr,
      ocrText: rawText,
      extraction: extraction,
      parties: parties,
    );
  }

  /// Pure combination of QR + OCR + party signals into a [ParsedSlip].
  /// Extracted so it can be unit-tested without any plugins.
  static ParsedSlip combine({
    String? imagePath,
    String? qrPayload,
    SlipQrData? qr,
    String? ocrText,
    required SlipExtraction extraction,
    SlipParties? parties,
  }) {
    // The QR's bank code is the SENDER's bank (authoritative); fall back to the
    // Thai party parse, then to the Latin keyword guess.
    final senderBank =
        qr?.bankCode ?? parties?.senderBankCode ?? extraction.bankCode;
    final transRef = qr?.transRef ?? extraction.transRef;

    var confidence = extraction.confidence;
    // Agreement between QR ref and OCR ref is a strong signal.
    if (qr?.transRef != null &&
        extraction.transRef != null &&
        qr!.transRef == extraction.transRef) {
      confidence += 0.2;
    }
    if (qr?.crcValid == true) confidence += 0.1;
    // Names are read by noisy Thai OCR, so they add only modest confidence.
    if (parties?.senderName != null) confidence += 0.1;
    if (parties?.receiverName != null) confidence += 0.05;
    if (parties?.receiverBankCode != null) confidence += 0.05;
    confidence = confidence.clamp(0, 1).toDouble();

    final source = extraction.amountCents == null && qr != null
        ? SlipSource.qrOnly
        : SlipSource.ocr;

    return ParsedSlip(
      source: source,
      imagePath: imagePath,
      qrPayload: qrPayload,
      bankCode: senderBank,
      transRef: transRef,
      amountCents: extraction.amountCents,
      occurredAt: extraction.occurredAt,
      senderName: parties?.senderName,
      senderBank: senderBank,
      receiverName: parties?.receiverName,
      receiverBank: parties?.receiverBankCode,
      rawOcrText: ocrText,
      confidence: confidence,
    );
  }
}
