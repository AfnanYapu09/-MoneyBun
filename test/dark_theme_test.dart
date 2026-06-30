import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/theme/app_theme.dart';
import 'package:moneybun/core/theme/colors.dart';
import 'package:moneybun/core/theme/typography.dart';

/// The colour a [Text] actually paints, after merging its style with the
/// ambient [DefaultTextStyle].
Color _resolvedTextColor(WidgetTester tester) {
  final richText = tester.widget<RichText>(find.byType(RichText));
  return (richText.text as TextSpan).style!.color!;
}

Future<void> _pump(WidgetTester tester, ThemeData theme) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Text('฿100', style: AppTypography.body(size: 15)),
      ),
    ),
  );
}

void main() {
  testWidgets('AppPalette is registered on both themes', (tester) async {
    expect(AppTheme.light().extension<AppPalette>(), isNotNull);
    expect(AppTheme.dark().extension<AppPalette>(), isNotNull);
  });

  testWidgets('unstyled text inherits light ink in light mode', (tester) async {
    await _pump(tester, AppTheme.light());
    // Light mode must be byte-identical to the original design ink.
    expect(_resolvedTextColor(tester), AppColors.ink);
  });

  testWidgets('unstyled text inherits a light ink in dark mode',
      (tester) async {
    await _pump(tester, AppTheme.dark());
    final color = _resolvedTextColor(tester);
    // In dark mode the same label must flip to the dark-theme ink…
    expect(color, AppPalette.dark.ink);
    // …which is genuinely light (not the old near-black ink that would be
    // invisible on the dark background).
    expect(color.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('scaffold background follows the theme', (tester) async {
    await _pump(tester, AppTheme.dark());
    expect(AppTheme.dark().scaffoldBackgroundColor, AppPalette.dark.bg);
    expect(AppTheme.light().scaffoldBackgroundColor, AppPalette.light.bg);
    // The dark background is genuinely dark.
    expect(AppPalette.dark.bg.computeLuminance(), lessThan(0.1));
  });
}
