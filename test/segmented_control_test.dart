import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/theme/app_theme.dart';
import 'package:moneybun/core/widgets/segmented_control.dart';

void main() {
  testWidgets('re-tapping the active segment does not fire onChanged', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SegmentedControl<int>(
            value: 1,
            onChanged: changes.add,
            segments: const [
              Segment(value: 1, label: 'One'),
              Segment(value: 2, label: 'Two'),
            ],
          ),
        ),
      ),
    );

    // The add/edit sheet clears its category on onChanged, so the active
    // segment must be a no-op — a stray tap must not wipe anything.
    await tester.tap(find.text('One'));
    expect(changes, isEmpty);

    await tester.tap(find.text('Two'));
    expect(changes, [2]);
  });
}
