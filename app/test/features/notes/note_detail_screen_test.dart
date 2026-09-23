import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/notes/ui/notes_screen.dart';
import 'package:nemo/features/photos/ui/photo_strip.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';

void main() {
  TextField bodyField(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('note-body')));

  /// Scrolls the format bar's own horizontal list -- not the page's, which
  /// `find.byType(Scrollable).first` would otherwise catch -- until
  /// [finder] is actually on screen and tappable.
  Future<void> scrollToolbar(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder.hitTestable(),
        200,
        scrollable: find.descendant(
          of: find.byType(NoteFormatToolbar),
          matching: find.byType(Scrollable),
        ),
      );

  appTest('the body is editable markdown source with no toggle', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '# Dough');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-edit-toggle')), findsNothing);
    final field = bodyField(tester);
    expect(field.controller, isA<MarkdownEditingController>());
    expect(field.controller!.text, '# Dough');
  });

  appTest('the toolbar shows only while the body has focus', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'milk');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('md-bold')), findsNothing);

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('md-bold')), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-title')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('md-bold')), findsNothing);
  });

  appTest('bold wraps the selection and keeps the body focused', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'milk');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-bold')));
    await tester.pump();

    expect(bodyField(tester).controller!.text, '**milk**');
    expect(bodyField(tester).focusNode!.hasFocus, isTrue);
  });

  appTest('ctrl+B bolds the selection', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'milk');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(bodyField(tester).controller!.text, '**milk**');
  });

  appTest('meta+B bolds the selection on macOS, where ctrl+B is native', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'milk');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(bodyField(tester).controller!.text, '**milk**');
    debugDefaultTargetPlatformOverride = null;
  });

  appTest('enter on a list line continues the list', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    final body = find.byKey(const Key('note-body'));
    await tester.enterText(body, '- milk');
    await tester.enterText(body, '- milk\n');
    await tester.pump();

    expect(bodyField(tester).controller!.text, '- milk\n- ');
  });

  appTest('typing saves after a pause without leaving the field', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    await tester.pump(const Duration(milliseconds: 500));
    expect((await harness.db.noteById('n1'))!.body, '');

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect((await harness.db.noteById('n1'))!.body, 'flour');
    expect(bodyField(tester).focusNode!.hasFocus, isTrue);
  });

  appTest('a sync arriving while typing does not replace the text', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'local');
    final stored = (await harness.db.noteById('n1'))!;
    await harness.container
        .read(notesRepositoryProvider)
        .save(stored.copyWith(body: 'remote'));
    await tester.pump();

    expect((await harness.db.noteById('n1'))!.body, 'remote');
    expect(bodyField(tester).controller!.text, 'local');
  });

  appTest('focusing the body without typing does not revert a sync that lands '
      'while it is focused, once it loses focus', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    expect(bodyField(tester).focusNode!.hasFocus, isTrue);

    final stored = (await harness.db.noteById('n1'))!;
    await harness.container
        .read(notesRepositoryProvider)
        .save(stored.copyWith(body: 'remote'));
    await tester.pump();
    expect((await harness.db.noteById('n1'))!.body, 'remote');

    // Unfocus without ever having typed -- there is nothing dirty here
    // to save, so the old ('dough') text the field is still showing
    // must not overwrite the sync that landed while it was focused.
    await tester.tap(find.byKey(const Key('note-title')));
    await tester.pumpAndSettle();

    expect((await harness.db.noteById('n1'))!.body, 'remote');
    expect(bodyField(tester).controller!.text, 'remote');
  });

  appTest('focusing the body without typing does not revert a sync that lands '
      'while it is focused, once the page is popped', (tester) async {
    // Reached from the list, like the not-found test above, so the page
    // has something to pop back to.
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    expect(bodyField(tester).focusNode!.hasFocus, isTrue);

    final stored = (await harness.db.noteById('n1'))!;
    await harness.container
        .read(notesRepositoryProvider)
        .save(stored.copyWith(body: 'remote'));
    await tester.pump();
    expect((await harness.db.noteById('n1'))!.body, 'remote');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect((await harness.db.noteById('n1'))!.body, 'remote');
  });

  appTest('open link opens a web link at the cursor', (tester) async {
    final opened = <Uri>[];
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes/n1',
      overrides: [
        openUrlProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote(
      'n1',
      'l1',
      title: 'Bread',
      body: '[recipe](https://x.y)',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection.collapsed(
      offset: 2,
    );
    await tester.pump();
    // `md-open-link` is the last, contextual button on the bar -- past the
    // fold on this screen's narrow test viewport until scrolled to.
    await scrollToolbar(tester, find.byKey(const Key('md-open-link')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-open-link')));
    await tester.pump();

    expect(opened, [Uri.parse('https://x.y')]);
  });

  appTest('inserting a link restores focus to the body and saves it', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'docs');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();

    // `md-link` sits last on the bar (no link at the cursor here, so
    // `md-open-link` never appears) -- also past the fold.
    await scrollToolbar(tester, find.byKey(const Key('md-link')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('md-link-url')), 'https://x.y');
    await tester.tap(find.byKey(const Key('md-link-ok')));
    await tester.pumpAndSettle();

    expect(bodyField(tester).controller!.text, '[docs](https://x.y)');
    expect(bodyField(tester).focusNode!.hasFocus, isTrue);

    await tester.pump(const Duration(milliseconds: 1100));
    expect((await harness.db.noteById('n1'))!.body, '[docs](https://x.y)');
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
    await tester.tap(find.byKey(const Key('confirm-delete-note')));
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

  appTest('deleting a note asks first; cancelling leaves it alone', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-delete-note')), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-title')), findsOneWidget);
    expect((await harness.db.noteById('n1'))!.isDeleted, isFalse);
  });

  appTest('confirming deletes the note, and the snackbar undo restores it', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-note')));
    await tester.pumpAndSettle();

    expect((await harness.db.noteById('n1'))!.isDeleted, isTrue);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect((await harness.db.noteById('n1'))!.isDeleted, isFalse);
  });

  appTest('deleting a note opened directly, with nothing else on the stack, '
      'lands on the notes list instead of crashing', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-note')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NotesScreen), findsOneWidget);
  });
}
