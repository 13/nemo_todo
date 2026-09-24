import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waits out the SnackBar on screen and expects it gone. One with an action
/// persists by default, sitting there until it is tapped.
Future<void> expectSnackBarTimesOut(WidgetTester tester) async {
  expect(find.byType(SnackBar), findsOneWidget);
  // Frames in steps: the timer starts once the entry animation is done.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(find.byType(SnackBar), findsNothing);
}
