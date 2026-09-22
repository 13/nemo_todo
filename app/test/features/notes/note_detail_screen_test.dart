import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('when a note is not found, show not-found message with AppBar', (
    tester,
  ) async {
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes/n1',
    );
    await harness.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();

    // Note n1 does not exist, so the not-found screen should appear
    expect(find.text('This note is no longer here.'), findsOneWidget);
    // AppBar is present; it provides the back button in real navigation contexts
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('opening a note that exists shows the title field', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-title')), findsOneWidget);
  });
}
