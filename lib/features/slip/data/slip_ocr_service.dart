import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR for slips. Two passes with different strengths:
///
/// * [recognizeLatin] — Google ML Kit's Latin recognizer. Fast & accurate for
///   Arabic digits, amounts, dates, references and Latin bank tokens. Does NOT
///   read Thai glyphs.
/// * [recognizeThai] — Tesseract (`tha`, bundled offline). Reads Thai names and
///   Thai bank labels that ML Kit can't, but is much slower and CPU-heavy, so
///   callers should only run it on images that already look like slips.
class SlipOcrService {
  /// Latin OCR (ML Kit). Cheap — always safe to run on every candidate image.
  Future<String> recognizeLatin(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// Thai OCR (Tesseract, offline). Returns `''` on any failure so a single
  /// unreadable image never aborts a gallery scan. Expensive — gate behind a
  /// "looks like a slip" check before calling.
  Future<String> recognizeThai(String imagePath) async {
    try {
      return await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'tha',
        args: const {
          'psm': '6', // assume a uniform block of text (a slip body)
          'preserve_interword_spaces': '1',
        },
      );
    } catch (_) {
      return '';
    }
  }
}
