import 'package:intl/intl.dart';

/// Money helpers. Amounts are stored as integer **cents** (สตางค์) everywhere —
/// never as `double` — to avoid floating point rounding errors.
class Money {
  const Money._();

  /// Known currency symbols. Amounts are always stored as integer cents; only
  /// the displayed symbol changes with the user's currency setting.
  static const Map<String, String> _symbols = {
    'THB': '฿',
    'USD': r'$',
    'EUR': '€',
    'JPY': '¥',
    'GBP': '£',
  };

  /// The active display symbol, updated from settings via [setCurrency].
  static String _symbol = '฿';

  /// Switch the display currency (e.g. `'THB'`, `'USD'`). Unknown codes fall
  /// back to the code itself as a prefix. Call from the app root so every
  /// amount reformats when the user changes currency.
  static void setCurrency(String code) {
    _symbol = _symbols[code] ?? '$code ';
  }

  static final NumberFormat _plain = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _whole = NumberFormat('#,##0', 'en_US');

  /// `123456` -> `฿1,234.56` (symbol follows the active currency).
  static String format(int cents, {bool symbol = true}) {
    final body = _plain.format(cents / 100.0);
    return symbol ? '$_symbol$body' : body;
  }

  /// Like [format] but drops `.00` for whole amounts (design style):
  /// `2000100` -> `฿20,001`, `84550` -> `฿845.50`, `-50000` -> `-฿500`
  /// (sign before the symbol — the naive formatting printed `฿-500`).
  static String compact(int cents, {bool symbol = true}) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final whole = abs % 100 == 0;
    final body = whole ? _whole.format(abs ~/ 100) : _plain.format(abs / 100.0);
    return symbol ? '$sign$_symbol$body' : '$sign$body';
  }

  /// Format with an explicit leading sign, e.g. `+฿1,234.56` / `-฿1,234.56`.
  static String formatSigned(int cents, {bool symbol = true}) {
    final sign = cents > 0 ? '+' : (cents < 0 ? '-' : '');
    return '$sign${format(cents.abs(), symbol: symbol)}';
  }

  /// Upper bound accepted from free-form input: ฿1,000,000,000. Keeps a stray
  /// paste / exponent-style typo from creating a ledger-breaking amount.
  static const int maxInputCents = 100000000000;

  /// Parse free-form user input (`"1,234.56"`, `"1234"`, `"1234.5"`) into cents.
  /// Returns `null` when the input is not a valid positive-or-zero amount.
  /// Plain decimal digits only — exponent notation ("1e5"), signs and other
  /// stray characters are rejected rather than guessed at.
  static int? parseToCents(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[฿$€¥£,\s]'), '');
    if (cleaned.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    final cents = (value * 100).round();
    return cents > maxInputCents ? null : cents;
  }

  /// `123456` -> `"1234.56"` for editable text fields.
  static String toEditString(int cents) => (cents / 100.0).toStringAsFixed(2);
}
