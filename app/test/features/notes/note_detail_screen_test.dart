import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';

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

  appTest(
    'when the open note is tombstoned elsewhere, show not-found with a back affordance',
    (tester) async {
      // Reach the note the way a person does: from the list, pushed on top
      // of it, so the stack can pop -- not as an initialLocation, which
      // would leave a single-page stack with no back button to assert on.
      final harness = await pumpApp(tester, initialLocation: '/notes');
      await harness.seedList('l1', 'Kitchen');
      await harness.seedNote('n1', 'l1', title: 'Bread');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-title')), findsOneWidget);

      // Another device tombstones the note while this page is still open.
      await harness.container.read(notesRepositoryProvider).delete('n1');
      await tester.pumpAndSettle();

      expect(find.text('This note is no longer here.'), findsOneWidget);
      // The page can still pop, so Flutter's AppBar auto-builds a real back
      // button -- unlike an initialLocation stack, where it would not.
      expect(find.byType(BackButton), findsOneWidget);
    },
  );
}
