import '../../../core/utils/app_date.dart';

/// What heuristic extraction could recover from a slip's OCR text.
class SlipExtraction {
  const SlipExtraction({
    this.amountCents,
    this.occurredAt,
    this.transRef,
    this.confidence = 0,
  });

  final int? amountCents;
  final DateTime? occurredAt;
  final String? transRef;
  final double confidence;
}

/// Heuristic extraction of amount / date-time / reference from the Latin OCR
/// text of a Thai bank slip. Reads Arabic digits only — names and banks are not
/// read at all (the amount is the single thing we care about).
class SlipExtractor {
  const SlipExtractor._();

  // A 2-decimal amount, comma-grouped ("1,234.56") or a plain digit run
  // ("1234.56" — OCR often drops the comma glyph), with an optional minus in
  // front (subsidy/discount lines print "-126.00"; OCR may render the minus as
  // -, −, – or —). The lookarounds pin the match to the whole number: without
  // them "1234.56" would match from the second digit and read as 234.56, and
  // "1,234.567" would be truncated to 1,234.56 instead of being skipped as
  // not-an-amount.
  static final _amount = RegExp(
    r'(?<!\d)([-−–—] ?)?((?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2})(?!\d)',
  );
  // A standalone whole-baht figure ("210 บาท") — government co-pay slips
  // (เป๋าตัง ไทยช่วยไทย / คนละครึ่ง) print no decimals at all. Tokens touching
  // letters, ',', '.', ':', '/', '-' or more digits are excluded so times
  // (21:54), dates (3/7/69), decimals, refs and "60/40" never qualify. Whole
  // figures are far noisier than 2-decimal ones (years, masked wallet IDs), so
  // they are only ever trusted through the co-pay arithmetic check below.
  static final _wholeAmount = RegExp(
    r'(?<![\d.,:/\-A-Za-z])([-−–—] ?)?(\d{1,3}(?:,\d{3})+|\d{1,7})'
    r'(?![\d.,:/\-A-Za-z])',
  );
  // dd/MM/yyyy or dd-MM-yy etc., optionally followed by HH:mm.
  static final _dateTime = RegExp(
    r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})(?:[^\d]{0,6}(\d{1,2}):(\d{2}))?',
  );
  static final _ref = RegExp(r'[A-Z0-9]{10,30}');

  static SlipExtraction extract(String ocrText) {
    final amountCents = _bestAmount(ocrText);
    final occurredAt = _firstDateTime(ocrText);
    final transRef = _firstRef(ocrText);

    var confidence = 0.2;
    if (amountCents != null) confidence += 0.4;
    if (occurredAt != null) confidence += 0.1;
    if (transRef != null) confidence += 0.1;

    return SlipExtraction(
      amountCents: amountCents,
      occurredAt: occurredAt,
      transRef: transRef,
      confidence: confidence.clamp(0, 1).toDouble(),
    );
  }

  static int? _bestAmount(String text) {
    final decimals = _matches(_amount, text);

    // Co-pay slips (ไทยช่วยไทยพลัส, คนละครึ่ง, ...) print three figures: the
    // goods total, the negative state subsidy and the amount the user actually
    // paid. The amount to record is the *paid* one — never the gross total.
    final copay = _copayNet([...decimals, ..._matches(_wholeAmount, text)]);
    if (copay != null) return copay;

    // Regular slip: the largest positive 2-decimal amount. Failing that, one
    // printed with a minus (some wallets render the debited amount negative).
    int? best;
    for (final m in decimals.where((m) => !m.negative)) {
      if (best == null || m.cents > best) best = m.cents;
    }
    if (best != null) return best;
    for (final m in decimals) {
      if (best == null || m.cents > best) best = m.cents;
    }
    return best;
  }

  /// The net (paid) amount of a co-pay slip, or null when the text doesn't
  /// carry that shape. Confirmed arithmetic only: some gross figure minus the
  /// subsidy line(s) must equal another printed figure — an exact three-way
  /// match, so stray numbers (years, masked wallet IDs) can't produce one.
  static int? _copayNet(List<_Money> all) {
    final negatives =
        all.where((m) => m.negative && m.cents > 0).map((m) => m.cents);
    if (negatives.isEmpty) return null;
    final positives = all
        .where((m) => !m.negative && m.cents > 0)
        .map((m) => m.cents)
        .toSet();
    // The subsidy is either a single line or the sum of several.
    final discounts = <int>{negatives.fold(0, (s, c) => s + c), ...negatives};
    final grosses = positives.toList()..sort((a, b) => b.compareTo(a));
    for (final gross in grosses) {
      for (final discount in discounts) {
        final net = gross - discount;
        if (net > 0 && positives.contains(net)) return net;
      }
    }
    return null;
  }

  static List<_Money> _matches(RegExp re, String text) {
    return [
      for (final m in re.allMatches(text))
        if (_toCents(m.group(2)!) case final int cents)
          _Money(cents, negative: m.group(1) != null),
    ];
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
    if (year < 100) {
      // 2-digit year. Thai slips usually print the Buddhist year, so a value
      // like 69 means พ.ศ.2569 (= 2026), while 26 means ค.ศ.2026. Buddhist
      // short years are currently in the 60s+, Gregorian ones in the 20s, so
      // map 60–99 onto the 2500s (Buddhist) and 00–59 onto the 2000s — then
      // normalizeYear strips the era. Without this, 69 became 2069 (far in the
      // future) and the slip's entry fell outside every visible month.
      year += year >= 60 ? 2500 : 2000;
    }
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

/// One money figure read from the OCR text: its magnitude in cents and whether
/// it was printed with a leading minus (a subsidy/discount line).
class _Money {
  const _Money(this.cents, {required this.negative});

  final int cents;
  final bool negative;
}
