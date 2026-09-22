import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/photos/ui/photo_strip.dart';
import 'package:nemo_core/nemo_core.dart';

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

  // Matches this file's own convention (appTest, not testWidgets): a note
  // page holds a drift stream and, once this task lands, a sync-engine
  // read too, both of which need appTest's extra teardown pumps.
  //
  // Reached by tapping into the note from the list, as the not-found test
  // above does -- not `initialLocation: '/notes/n1'`. Delete pops the page,
  // and a note opened as the sole initial route has nothing below it on
  // the stack to pop back to, which go_router refuses.
  appTest('a note can be pinned, moved and deleted', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedList('l2', 'Garage');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-pin')));
    await tester.pumpAndSettle();
    expect((await harness.db.noteById('n1'))!.pinned, isTrue);

    await tester.tap(find.byKey(const Key('note-move')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage').last);
    await tester.pumpAndSettle();
    expect((await harness.db.noteById('n1'))!.listId, 'l2');

    await tester.tap(find.byKey(const Key('note-delete')));
    await tester.pumpAndSettle();
    expect((await harness.db.noteById('n1'))!.isDeleted, isTrue);
  });

  appTest('a picture added to a note hangs on the note', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await harness.addPhotoTo(PhotoParent.note, 'n1');
    await tester.pumpAndSettle();

    final photos = await harness.db.photosOfParent(PhotoParent.note, 'n1');
    expect(photos.single.parentId, 'n1');
    expect(find.byType(PhotoStrip), findsOneWidget);
  });
}
