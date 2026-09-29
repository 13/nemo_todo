import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_style.dart';

import '../support/a11y.dart';
import '../support/pump_app.dart';

/// Every main screen, in every style, light and dark, against Flutter's
/// accessibility guidelines: targets a finger can hit, a label on every
/// one a screen reader lands on, and text that stands out from what is
/// behind it.
void main() {
  for (final style in AppStyle.values) {
    for (final dark in [false, true]) {
      final shade = dark ? 'dark' : 'light';
      for (final MapEntry(key: name, value: location) in a11yScreens.entries) {
        appTest('${style.name} $shade: $name meets the guidelines', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await pumpA11y(tester, style: style, location: location, dark: dark);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          // Flutter's own check passes any target touching a screen or list
          // edge; this one measures those too.
          await expectLater(tester, meetsGuideline(fingerTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  }

  // Every accent Settings offers, on the screen with the most colour on it:
  // the checks, today's dates and the buttons take the accent.
  for (final style in AppStyle.values) {
    for (final dark in [false, true]) {
      for (var accent = 0; accent < 8; accent++) {
        appTest('${style.name} ${dark ? 'dark' : 'light'} in accent $accent: '
            'Today is legible', (tester) async {
          final handle = tester.ensureSemantics();
          await pumpA11y(
            tester,
            style: style,
            location: a11yScreens['Today']!,
            dark: dark,
            accent: accent,
          );
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  }

  // A Mac's rows and buttons are denser than a finger needs; a window that
  // wide has a pointer. Labels and contrast still hold there.
  for (final dark in [false, true]) {
    appTest('macos ${dark ? 'dark' : 'light'} on a desktop is labelled '
        'and legible', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpA11y(
        tester,
        style: AppStyle.macos,
        location: a11yScreens['Today']!,
        dark: dark,
        size: const Size(1280, 820),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
