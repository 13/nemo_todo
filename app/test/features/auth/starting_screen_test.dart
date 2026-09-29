import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/features/auth/ui/starting_screen.dart';

void main() {
  testWidgets('shows the loading screen mark in the middle of the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const StartingScreen()),
    );
    // Centred on the whole screen, as the page's loading screen is, so the
    // one fades into the other in place.
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      tester.getCenter(find.byType(NemoSplashMark)),
      size.center(Offset.zero),
    );
  });
}
