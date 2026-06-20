import 'package:mobile_scanner/mobile_scanner.dart';

/// Reads a QR/barcode from a still slip image using mobile_scanner's
/// `analyzeImage`. The controller is created lazily and **reused** across a
/// whole scan batch — creating one per image was a major scan-time cost — so
/// callers must invoke [dispose] when the batch finishes.
class SlipQrScanner {
  MobileScannerController? _controller;

  MobileScannerController _ensure() =>
      _controller ??= MobileScannerController();

  Future<String?> scanFromImage(String imagePath) async {
    try {
      final capture = await _ensure().analyzeImage(imagePath);
      if (capture == null) return null;
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw != null && raw.isNotEmpty) return raw;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Release the shared controller. Safe when none was created; the next
  /// [scanFromImage] lazily makes a fresh one.
  Future<void> dispose() async {
    final c = _controller;
    _controller = null;
    if (c != null) await c.dispose();
  }
}
