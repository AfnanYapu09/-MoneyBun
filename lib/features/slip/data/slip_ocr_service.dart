import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR using ML Kit's Latin recognizer. Latin reads Arabic digits,
/// amounts, dates and Latin bank tokens — it does NOT read Thai glyphs (that's a
/// documented ML Kit limitation), so Thai names come from the verify API.
class SlipOcrService {
  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
