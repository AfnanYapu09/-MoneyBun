import 'package:intl/intl.dart';

/// Money helpers. Amounts are stored as integer **cents** (สตางค์) everywhere —
/// never as `double` — to avoid floating point rounding errors.
class Money {
  const Money._();

  static final NumberFormat _baht = NumberFormat.currency(
    locale: 'th_TH',
    symbol: '฿',
    decimalDigits: 2,
  );

  static final NumberFormat _plain = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _whole = NumberFormat('#,##0', 'en_US');

  /// `123456` -> `฿1,234.56`
  static String format(int cents, {bool symbol = true}) {
    final value = cents / 100.0;
    return symbol ? _baht.format(value) : _plain.format(value);
  }

  /// Like [format] but drops `.00` for whole-baht amounts (design style):
  /// `2000100` -> `฿20,001`, `84550` -> `฿845.50`.
  static String compact(int cents, {bool symbol = true}) {
    final whole = cents % 100 == 0;
    final body =
        whole ? _whole.format(cents ~/ 100) : _plain.format(cents / 100.0);
    return symbol ? '฿$body' : body;
  }

  /// Format with an explicit leading sign, e.g. `+฿1,234.56` / `-฿1,234.56`.
  static String formatSigned(int cents, {bool symbol = true}) {
    final sign = cents > 0 ? '+' : (cents < 0 ? '-' : '');
    return '$sign${format(cents.abs(), symbol: symbol)}';
  }

  /// Parse free-form user input (`"1,234.56"`, `"1234"`, `"1234.5"`) into cents.
  /// Returns `null` when the input is not a valid positive-or-zero amount.
  static int? parseToCents(String input) {
    final cleaned = input.trim().replaceAll(',', '').replaceAll('฿', '').trim();
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value < 0) return null;
    return (value * 100).round();
  }

  /// `123456` -> `"1234.56"` for editable text fields.
  static String toEditString(int cents) => (cents / 100.0).toStringAsFixed(2);
}
