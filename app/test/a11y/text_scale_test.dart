import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_style.dart';

import '../support/a11y.dart';
import '../support/pump_app.dart';

/// The main screens with the system's text at twice its size, as someone
/// who has turned it up in Android's display settings sees them. An
/// overflow reports itself as an error, which fails the test on its own;
/// the checks below say so outright.
void main() {
  for (final style in AppStyle.values) {
    for (final MapEntry(key: name, value: location) in a11yScreens.entries) {
      appTest('${style.name}: $name fits text at 200%', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpA11y(tester, style: style, location: location);
        expect(tester.takeException(), isNull);
        // What is below the fold overflows only once it is scrolled to.
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.fling(scrollable.first, const Offset(0, -2000), 3000);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  // A Mac's window, with the sidebar beside the list.
  appTest('macos on a desktop fits text at 200%', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpA11y(
      tester,
      style: AppStyle.macos,
      location: a11yScreens['Today']!,
      size: const Size(1280, 820),
    );
    expect(tester.takeException(), isNull);
  });
}
