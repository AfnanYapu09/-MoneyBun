import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR for slips: Google ML Kit's Latin recognizer only. Fast &
/// accurate for Arabic digits, amounts, dates and references — which is all the
/// pipeline needs now that names/banks are no longer read.
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

  /// Release the shared ML Kit recognizer. Safe when none was created.
  Future<void> dispose() async {
    final r = _latin;
    _latin = null;
    if (r != null) await r.close();
  }
}
