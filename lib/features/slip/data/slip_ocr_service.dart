import 'dart:io';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device OCR for slips. Two passes with different strengths:
///
/// * [recognizeLatin] — Google ML Kit's Latin recognizer. Fast & accurate for
///   Arabic digits, amounts, dates, references and Latin bank tokens. Does NOT
///   read Thai glyphs.
/// * [recognizeThai] — Tesseract (`tha`, bundled offline) on a pre-processed
///   (grayscale + upscaled + contrast-boosted) copy of the image. Reads Thai
///   names that ML Kit can't, but is slow, so callers gate it behind a
///   "looks like a slip" check.
///
/// The ML Kit recognizer is reused across a scan batch and released via
/// [dispose] (constructing one per image was a major scan-time cost).
class SlipOcrService {
  TextRecognizer? _latin;

  TextRecognizer _ensureLatin() =>
      _latin ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Latin OCR (ML Kit). Cheap — safe to run on every candidate image.
  Future<String> recognizeLatin(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _ensureLatin().processImage(input);
    return result.text;
  }

  /// Thai OCR (Tesseract, offline). Pre-processes the image to give the LSTM
  /// model clean, high-contrast text. Returns `''` on any failure so a single
  /// unreadable image never aborts a scan.
  Future<String> recognizeThai(String imagePath) async {
    String? temp;
    try {
      temp = await _preprocess(imagePath);
      return await FlutterTesseractOcr.extractText(
        temp ?? imagePath,
        language: 'tha',
        args: const {
          'psm': '6', // assume a uniform block of text (a slip body)
          'preserve_interword_spaces': '1',
        },
      );
    } catch (_) {
      return '';
    } finally {
      if (temp != null) {
        try {
          await File(temp).delete();
        } catch (_) {
          // best-effort cleanup of the preprocessed temp file
        }
      }
    }
  }

  /// Release the shared ML Kit recognizer. Safe when none was created.
  Future<void> dispose() async {
    final r = _latin;
    _latin = null;
    if (r != null) await r.close();
  }

  /// Grayscale + upscale (if small) + contrast boost, written to a temp PNG.
  /// Returns the temp path, or null on failure (caller OCRs the original).
  Future<String?> _preprocess(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;
      if (image.width < 1000) {
        image = img.copyResize(image, width: 1600);
      }
      image = img.grayscale(image);
      image = img.adjustColor(image, contrast: 1.6);
      final dir = await getTemporaryDirectory();
      final out = p.join(
        dir.path,
        'slip_ocr_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await File(out).writeAsBytes(img.encodePng(image));
      return out;
    } catch (_) {
      return null;
    }
  }
}
