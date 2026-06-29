import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/calculator.dart';

/// Signature for [showAmountCalculator]'s live callback: [value] is the text to
/// show in the amount field, [history] is the just-computed expression to show
/// above it (e.g. "2+2 =") — empty while the user is still typing.
typedef CalcChanged = void Function(String value, String history);

/// Opens the in-app calculator keypad as a docked bottom sheet (no display of
/// its own — what the user presses appears live in the field via [onChanged]).
/// Seeded with [initial] (the field's current text). Pressing `=` resolves the
/// expression, pushes the result + the "2+2 =" history through [onChanged], and
/// keeps the keypad open; the user dismisses it themselves (drag / tap outside).
///
/// The caller resolves whatever expression is left in the field once this
/// future completes (covers drag-down and tap-outside).
///
/// [accent] tints the operator and `=` keys; it defaults to the app's primary
/// colour (terracotta orange) so the keypad always follows the app theme.
Future<void> showAmountCalculator(
  BuildContext context, {
  required String initial,
  required CalcChanged onChanged,
  Color? accent,
}) {
  final color = accent ?? Theme.of(context).colorScheme.primary;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.transparent,
    backgroundColor: Colors.transparent,
    builder: (_) => _CalculatorSheet(
      initial: initial,
      accent: color,
      onChanged: onChanged,
    ),
  );
}

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet({
    required this.initial,
    required this.accent,
    required this.onChanged,
  });

  final String initial;
  final Color accent;
  final CalcChanged onChanged;

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
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
    // "=" resolves the expression, shows the result in the field and surfaces
    // the "2+2 =" history above it, but keeps the keypad open — the user
    // dismisses it themselves (tap away / drag down).
    if (key == '=') {
      final v = Calculator.evaluate(_expr);
      if (v != null) {
        // Only a real calculation (it used an operator) is worth a history
        // line; "100 =" for a plain number is just noise, so leave it blank.
        final history = Calculator.hasOperator(_expr) ? '$_expr =' : '';
        _expr = Calculator.formatResult(v);
        widget.onChanged(_expr, history);
      }
      return;
    }
    // The sheet itself shows nothing, so no rebuild is needed — just push the
    // updated expression into the field (history clears until the next "=").
    _expr = Calculator.input(_expr, key);
    widget.onChanged(_expr, '');
  }

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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

/// Small expression line shown above the amount (e.g. "2+2 =") right after the
/// user presses "=". Renders nothing while [text] is empty, so screens can keep
/// it in the tree unconditionally.
class CalcHistoryLine extends StatelessWidget {
  const CalcHistoryLine(this.text, {super.key, this.reserveHeight});

  final String text;

  /// When set, the line always occupies this height (showing [text] or nothing)
  /// so the box around it never resizes as the history appears / disappears.
  /// When null it collapses to zero height while [text] is empty.
  final double? reserveHeight;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.heading(
        size: 14,
        weight: FontWeight.w500,
        color: AppColors.terra,
      ),
    );
    final reserved = reserveHeight;
    if (reserved != null) {
      return SizedBox(
        height: reserved,
        width: double.infinity,
        child: Align(
          alignment: Alignment.centerLeft,
          child: text.isEmpty ? null : label,
        ),
      );
    }
    if (text.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: label,
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
