import 'package:mobile_scanner/mobile_scanner.dart';

/// Reads a QR/barcode from a still slip image (gallery or camera capture) using
/// mobile_scanner's `analyzeImage`.
class SlipQrScanner {
  Future<String?> scanFromImage(String imagePath) async {
    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(imagePath);
      if (capture == null) return null;
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw != null && raw.isNotEmpty) return raw;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }
}
