/// A tiny, dependency-free calculator engine for the in-app amount keypad.
///
/// The keypad builds up a display *expression* string using the on-screen
/// operator glyphs (`+ − × ÷`); [evaluate] parses that string with correct
/// operator precedence (× ÷ before + −) and returns the result. Keeping the
/// engine a set of pure functions makes it trivial to unit-test and keeps the
/// widget layer dumb.
class Calculator {
  const Calculator._();

  /// On-screen operator glyphs (what the user sees in the expression).
  static const String add = '+';
  static const String subtract = '−'; // −  (minus sign, not hyphen)
  static const String multiply = '×'; // ×
  static const String divide = '÷'; // ÷
  static const String percent = '%';

  static const Set<String> _operators = {add, subtract, multiply, divide};

  /// Whether [expr] currently contains an arithmetic operator (i.e. it is a
  /// computation, not just a single number) — drives whether the keypad shows
  /// the "100×2 =" hint line above the result.
  static bool hasOperator(String expr) {
    for (final op in _operators) {
      if (expr.contains(op)) return true;
    }
    return false;
  }

  /// Apply a single key press to [expr] and return the new expression.
  ///
  /// Keys: a digit `'0'`–`'9'`, `'.'`, an operator glyph ([add]/[subtract]/
  /// [multiply]/[divide]), [percent], `'back'` (delete last char) or `'clear'`
  /// (reset to empty).
  static String input(String expr, String key) {
    switch (key) {
      case 'clear':
        return '';
      case 'back':
        return expr.isEmpty ? '' : expr.substring(0, expr.length - 1);
      case percent:
        return _applyPercent(expr);
      case '.':
        return _appendDot(expr);
    }
    if (_operators.contains(key)) return _appendOperator(expr, key);
    if (key.length == 1 && _isDigit(key)) return _appendDigit(expr, key);
    return expr; // ignore anything unexpected
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }

  static String _appendDigit(String expr, String d) {
    final n = _trailingNumber(expr);
    // Collapse a lone leading zero: "0" + "5" -> "5", "0" + "0" -> "0".
    if (n == '0') {
      if (d == '0') return expr;
      return expr.substring(0, expr.length - 1) + d;
    }
    return expr + d;
  }

  static String _appendDot(String expr) {
    final n = _trailingNumber(expr);
    if (n.contains('.')) return expr; // one dot per number
    if (n.isEmpty) return '${expr}0.'; // start a decimal cleanly: "0."
    return '$expr.';
  }

  static String _appendOperator(String expr, String op) {
    if (expr.isEmpty) return expr; // no leading operator
    final last = expr[expr.length - 1];
    if (_operators.contains(last)) {
      // Swap the pending operator ("5+" then "×" -> "5×").
      return expr.substring(0, expr.length - 1) + op;
    }
    if (last == '.') {
      // Drop a dangling dot before the operator ("5." -> "5+").
      return '${expr.substring(0, expr.length - 1)}$op';
    }
    return expr + op;
  }

  /// Percent is contextual, the way a phone calculator behaves:
  /// `a + b%` / `a − b%` treat `b` as a percentage *of a* (so `200+7% = 214`),
  /// while `a × b%` / `a ÷ b%` and a bare `b%` just mean `b / 100`.
  static String _applyPercent(String expr) {
    final n = _trailingNumber(expr);
    if (n.isEmpty || n == '.') return expr;
    final value = double.tryParse(n);
    if (value == null) return expr;
    final head = expr.substring(0, expr.length - n.length);
    double result;
    if (head.isEmpty) {
      result = value / 100;
    } else {
      final op = head[head.length - 1];
      if (op == add || op == subtract) {
        final base = evaluate(head.substring(0, head.length - 1)) ?? 0;
        result = base * value / 100;
      } else {
        result = value / 100;
      }
    }
    return head + _literal(result);
  }

  /// True when [expr] ends with an operator or a dot — i.e. it is not yet a
  /// complete number and that trailing character should be ignored / trimmed.
  static bool _endsWithOpOrDot(String expr) {
    if (expr.isEmpty) return false;
    final last = expr[expr.length - 1];
    return _operators.contains(last) || last == '.';
  }

  /// The run of digits / decimal point at the end of [expr] (`''` when it ends
  /// with an operator or is empty).
  static String _trailingNumber(String expr) {
    var i = expr.length;
    while (i > 0) {
      final c = expr[i - 1];
      if (_isDigit(c) || c == '.') {
        i--;
      } else {
        break;
      }
    }
    return expr.substring(i);
  }

  /// Evaluate a display [expr] like `"100×2"`. Returns `null` when it's empty
  /// or cannot be evaluated (malformed, or a divide by zero). A trailing
  /// operator or dot is ignored so half-typed input like `"100×"` still yields
  /// `100`.
  static double? evaluate(String expr) {
    var s = expr.trim();
    while (_endsWithOpOrDot(s)) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty) return null;

    final tokens = _tokenize(s);
    if (tokens == null) return null;

    // Pass 1: resolve × and ÷ left-to-right, folding into `nums`.
    final nums = <double>[tokens[0] as double];
    final ops = <String>[];
    for (var i = 1; i < tokens.length; i += 2) {
      final op = tokens[i] as String;
      final rhs = tokens[i + 1] as double;
      if (op == multiply) {
        nums[nums.length - 1] = nums.last * rhs;
      } else if (op == divide) {
        if (rhs == 0) return null; // divide by zero
        nums[nums.length - 1] = nums.last / rhs;
      } else {
        ops.add(op);
        nums.add(rhs);
      }
    }

    // Pass 2: resolve + and − left-to-right.
    var total = nums[0];
    for (var i = 0; i < ops.length; i++) {
      total = ops[i] == add ? total + nums[i + 1] : total - nums[i + 1];
    }

    if (total.isNaN || total.isInfinite) return null;
    return total;
  }

  /// Split into `[number, op, number, op, …]`; returns `null` on malformed
  /// input (an operator with no left/right operand, a bad number).
  static List<Object>? _tokenize(String s) {
    final out = <Object>[];
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (_operators.contains(c)) {
        if (buf.isEmpty) return null;
        final v = double.tryParse(buf.toString());
        if (v == null) return null;
        out.add(v);
        out.add(c);
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    if (buf.isEmpty) return null;
    final v = double.tryParse(buf.toString());
    if (v == null) return null;
    out.add(v);
    return out;
  }

  /// Result formatted for the amount field: whole numbers print without a
  /// decimal part; otherwise up to two decimal places with trailing zeros
  /// trimmed (`200.0 → "200"`, `200.5 → "200.5"`, `200.555 → "200.56"`).
  static String formatResult(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return _trimZeros(value.toStringAsFixed(2));
  }

  /// A higher-precision literal used when inlining a computed value (percent)
  /// back into the expression, so precision isn't lost mid-calculation.
  static String _literal(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return _trimZeros(value.toStringAsFixed(6));
  }

  static String _trimZeros(String s) {
    if (!s.contains('.')) return s;
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
