@Tags(['design'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';

/// Renders the painted mark to `build/screens/mark.png` the way the screens
/// are rendered next door: build output to look at, not a stored golden.
///
///   flutter test test/design --update-goldens
void main() {
  testWidgets('mark and tile', (tester) async {
    tester.view.physicalSize = const Size(600, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NemoMark(size: 200),
                SizedBox(width: 40),
                NemoLogoTile(size: 200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/screens/mark.png'),
    );
  });
}
