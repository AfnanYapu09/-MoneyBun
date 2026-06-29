import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/calculator.dart';

/// Opens the in-app amount calculator as a bottom sheet, seeded with [initial]
/// (the field's current text, e.g. `"1,234.56"` or `"฿200"`). Returns the
/// computed amount as a plain edit string (`"200"`, `"200.5"`) when the user
/// taps **เสร็จสิ้น**, or `null` if dismissed without entering anything.
///
/// [accent] tints the operator and `=` keys; it defaults to the app's primary
/// colour (terracotta orange) so the keypad always follows the app theme.
Future<String?> showAmountCalculator(
  BuildContext context, {
  required String initial,
  Color? accent,
}) {
  final color = accent ?? Theme.of(context).colorScheme.primary;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CalculatorSheet(initial: initial, accent: color),
  );
}

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet({required this.initial, required this.accent});

  final String initial;
  final Color accent;

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  static final _money = NumberFormat('#,##0.##', 'en_US');

  late String _expr = _seed(widget.initial);

  /// Normalise the field's existing text into a starting expression. A zero or
  /// unparseable value starts empty so the first digit replaces it cleanly.
  static String _seed(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(cleaned);
    if (value == null || value == 0) return '';
    return Calculator.formatResult(value);
  }

  void _onKey(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == '=') {
        final v = Calculator.evaluate(_expr);
        if (v != null) _expr = Calculator.formatResult(v);
      } else {
        _expr = Calculator.input(_expr, key);
      }
    });
  }

  void _done() {
    final v = Calculator.evaluate(_expr);
    Navigator.of(context).pop(v == null ? null : Calculator.formatResult(v));
  }

  @override
  Widget build(BuildContext context) {
    final value = Calculator.evaluate(_expr);
    final result = value == null ? '0' : _money.format(value);
    final showExpr = Calculator.hasOperator(_expr);

    final labelStyle = AppTypography.heading(
      size: 13,
      weight: FontWeight.w500,
      color: AppColors.ink3,
    );
    final doneStyle = AppTypography.heading(
      size: 16,
      weight: FontWeight.w600,
      color: widget.accent,
    );
    final exprStyle = AppTypography.heading(
      size: 16,
      weight: FontWeight.w500,
      color: widget.accent,
    );
    final symbolStyle = AppTypography.heading(
      size: 24,
      weight: FontWeight.w500,
      color: AppColors.ink3,
    );
    final resultStyle = AppTypography.heading(
      size: 44,
      weight: FontWeight.w600,
      color: AppColors.ink,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: Tokens.sheetTop,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 8, 0),
              child: Row(
                children: [
                  Text('เครื่องคิดเลข', style: labelStyle),
                  const Spacer(),
                  TextButton(
                    onPressed: _done,
                    child: Text('เสร็จสิ้น', style: doneStyle),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    showExpr ? '$_expr =' : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: exprStyle,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('฿', style: symbolStyle),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          result,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: resultStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CalculatorKeypad(accent: widget.accent, onKey: _onKey),
          ],
        ),
      ),
    );
  }
}

/// The orange calculator keypad — a 4-column grid of number, operator and `=`
/// keys. Each press is sent to [onKey] using the key strings [Calculator.input]
/// understands (digits, `'.'`, operator glyphs, `'%'`, `'clear'`, `'back'`),
/// plus `'='`.
class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.onKey,
    this.accent = AppColors.terra,
  });

  final ValueChanged<String> onKey;
  final Color accent;

  static const List<List<_Key>> _layout = [
    [
      _Key(value: 'clear', label: 'AC', kind: _Kind.operator, flex: 2),
      _Key(value: '%', kind: _Kind.operator),
      _Key(value: '÷', kind: _Kind.operator),
    ],
    [
      _Key(value: '7'),
      _Key(value: '8'),
      _Key(value: '9'),
      _Key(value: '×', kind: _Kind.operator),
    ],
    [
      _Key(value: '4'),
      _Key(value: '5'),
      _Key(value: '6'),
      _Key(value: '−', kind: _Kind.operator),
    ],
    [
      _Key(value: '1'),
      _Key(value: '2'),
      _Key(value: '3'),
      _Key(value: '+', kind: _Kind.operator),
    ],
    [
      _Key(value: '.'),
      _Key(value: '0'),
      _Key(value: 'back', icon: Icons.backspace_outlined),
      _Key(value: '=', kind: _Kind.equals),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in _layout)
            Row(
              children: [
                for (final k in row)
                  Expanded(
                    flex: k.flex,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: _KeyButton(data: k, accent: accent, onKey: onKey),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _Kind { number, operator, equals }

class _Key {
  const _Key({
    required this.value,
    this.label,
    this.kind = _Kind.number,
    this.flex = 1,
    this.icon,
  });

  /// The key string handed to [Calculator.input] / `onKey`.
  final String value;

  /// What to show on the key, when it differs from [value] (e.g. "AC").
  final String? label;
  final _Kind kind;
  final int flex;
  final IconData? icon;

  String get display => label ?? value;
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.data,
    required this.accent,
    required this.onKey,
  });

  final _Key data;
  final Color accent;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (data.kind) {
      _Kind.number => (AppColors.paper, AppColors.ink),
      _Kind.operator => (accent.withValues(alpha: 0.12), accent),
      _Kind.equals => (accent, AppColors.reverse),
    };
    // "AC" reads as a word; every other key is a single large glyph.
    final fontSize = data.value == 'clear' ? 19.0 : 24.0;
    final keyStyle = AppTypography.heading(
      size: fontSize,
      weight: FontWeight.w500,
      color: fg,
    );
    final child = data.icon != null
        ? Icon(data.icon, size: 24, color: fg)
        : Text(data.display, style: keyStyle);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onKey(data.value),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(height: 58, child: Center(child: child)),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }
}
