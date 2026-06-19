import '../../../core/constants/bank_codes.dart';
import '../../../core/utils/app_date.dart';

/// What heuristic extraction could recover from a slip's OCR text.
class SlipExtraction {
  const SlipExtraction({
    this.amountCents,
    this.occurredAt,
    this.transRef,
    this.bankCode,
    this.confidence = 0,
  });

  final int? amountCents;
  final DateTime? occurredAt;
  final String? transRef;
  final String? bankCode;
  final double confidence;
}

/// Heuristic extraction of amount / date-time / reference / bank from the Latin
/// OCR text of a Thai bank slip. This pass reads Arabic digits and Latin bank
/// tokens only — Thai names and Thai bank labels are recovered separately by
/// [SlipPartyExtractor] from the on-device Thai (Tesseract) OCR pass.
class SlipExtractor {
  const SlipExtractor._();

  static final _amount = RegExp(r'\d{1,3}(?:,\d{3})*\.\d{2}');
  // dd/MM/yyyy or dd-MM-yy etc., optionally followed by HH:mm.
  static final _dateTime = RegExp(
    r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})(?:[^\d]{0,6}(\d{1,2}):(\d{2}))?',
  );
  static final _ref = RegExp(r'[A-Z0-9]{10,30}');

  static SlipExtraction extract(String ocrText) {
    final amountCents = _largestAmount(ocrText);
    final occurredAt = _firstDateTime(ocrText);
    final transRef = _firstRef(ocrText);
    final bank = BankCodes.detectFromText(ocrText);

    var confidence = 0.2;
    if (amountCents != null) confidence += 0.4;
    if (occurredAt != null) confidence += 0.1;
    if (transRef != null) confidence += 0.1;
    if (bank != null) confidence += 0.1;

    return SlipExtraction(
      amountCents: amountCents,
      occurredAt: occurredAt,
      transRef: transRef,
      bankCode: bank?.code,
      confidence: confidence.clamp(0, 1).toDouble(),
    );
  }

  static int? _largestAmount(String text) {
    int? best;
    for (final m in _amount.allMatches(text)) {
      final cents = _toCents(m.group(0)!);
      if (cents != null && (best == null || cents > best)) best = cents;
    }
    return best;
  }

  static int? _toCents(String s) {
    final cleaned = s.replaceAll(',', '');
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }

  static DateTime? _firstDateTime(String text) {
    final m = _dateTime.firstMatch(text);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    var year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000; // 2-digit year
    year = AppDate.normalizeYear(year); // strip Buddhist era if present
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final hour = int.tryParse(m.group(4) ?? '') ?? 0;
    final minute = int.tryParse(m.group(5) ?? '') ?? 0;
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  static String? _firstRef(String text) {
    for (final m in _ref.allMatches(text.toUpperCase())) {
      final token = m.group(0)!;
      if (RegExp(r'\d').hasMatch(token) && RegExp(r'[A-Z]').hasMatch(token)) {
        return token;
      }
    }
    // Fallback: a long all-digit run (some banks use numeric refs).
    final numeric = RegExp(r'\d{12,30}').firstMatch(text);
    return numeric?.group(0);
  }
}
