import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  appTest('the body renders as markdown and edits as its source', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '# Dough');
    await tester.pumpAndSettle();

    // Read mode: the hash is markup, not text on screen.
    expect(find.text('# Dough'), findsNothing);
    expect(find.text('Dough'), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-edit-toggle')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-body')))
          .controller!
          .text,
      '# Dough',
    );
  });
}
