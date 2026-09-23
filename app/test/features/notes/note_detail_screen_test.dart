import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/notes/ui/notes_screen.dart';
import 'package:nemo/features/photos/ui/photo_strip.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';

/// A [NotesRepository] whose `updateText` -- the screen's save path --
/// waits on [_gate] before writing anything.
///
/// Used to make the gap between `_save` kicking a write off and the write
/// actually landing observable from a test -- the in-memory test database
/// otherwise resolves that gap well within a single microtask, before the
/// widget's next frame, which is not how it works in production (drift runs
/// the write in a background isolate there).
class _GatedNotesRepository extends NotesRepository {
  _GatedNotesRepository(super._db, super._clock, super._newId, this._gate);

  final Completer<void> _gate;

  @override
  Future<void> updateText(String id, {String? title, String? body}) async {
    await _gate.future;
    await super.updateText(id, title: title, body: body);
  }
}

/// A [NotesRepository] whose [watch] delivers every emission [_lag] late.
///
/// Stands in for production, where drift runs on a background isolate: the
/// row a `save` just wrote reaches the note stream some time after `save`
/// itself has returned, so for that window the provider still holds the
/// pre-write note.
class _LaggingNotesRepository extends NotesRepository {
  _LaggingNotesRepository(super._db, super._clock, super._newId, this._lag);

  final Duration _lag;

  @override
  Stream<Note?> watch(String id) => super.watch(id).asyncMap((note) async {
    await Future<void>.delayed(_lag);
    return note;
  });
}

/// A [NotesRepository] whose text writes always fail, as a full disk or a
/// closed database would.
class _FailingNotesRepository extends NotesRepository {
  _FailingNotesRepository(super._db, super._clock, super._newId);

  @override
  Future<void> save(Note note) async => throw StateError('disk full');

  @override
  Future<void> updateText(String id, {String? title, String? body}) async =>
      throw StateError('disk full');
}

/// A [NotesRepository] whose first text write fails and later ones land.
class _FailingOnceNotesRepository extends NotesRepository {
  _FailingOnceNotesRepository(super._db, super._clock, super._newId);

  var _failed = false;

  @override
  Future<void> save(Note note) async {
    if (!_failed) {
      _failed = true;
      throw StateError('disk full');
    }
    await super.save(note);
  }

  @override
  Future<void> updateText(String id, {String? title, String? body}) async {
    if (!_failed) {
      _failed = true;
      throw StateError('disk full');
    }
    await super.updateText(id, title: title, body: body);
  }
}

void main() {
  TextField bodyField(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('note-body')));

  TextField titleField(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('note-title')));

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
    // `flutter_test` checks that no foundation debug variable is still set
    // once the test body returns, before `addTearDown` callbacks run -- so
    // an `addTearDown` reset here is too late and trips that check itself.
    // A manual reset in `finally` runs in time, on both the pass and the
    // throw path.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
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

      // Ctrl+B is left to the platform's own text field on macOS/iOS -- not
      // bound here, unlike meta+B above -- so it must not touch the text.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(bodyField(tester).controller!.text, '**milk**');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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

  appTest(
    'an edit keeps its text on unfocus until the in-flight save lands, not '
    'just until it is kicked off',
    (tester) async {
      final gate = Completer<void>();
      final harness = await pumpApp(
        tester,
        initialLocation: '/notes/n1',
        overrides: [
          notesRepositoryProvider.overrideWith(
            (ref) => _GatedNotesRepository(
              ref.watch(appDatabaseProvider),
              ref.watch(hlcClockProvider),
              ref.watch(idGeneratorProvider),
              gate,
            ),
          ),
        ],
      );
      await harness.seedList('l1', 'Kitchen');
      await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('note-body')), 'flour');
      // Losing focus kicks `_save` off -- and, through its own `setState`,
      // forces exactly the rebuild that would run `_fill` early against the
      // still-unwritten note if the dirty flag were cleared up front.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // The gated write hasn't landed yet -- the store still holds the old
      // text -- so the field must still show what was typed, not fall back
      // to it.
      expect((await harness.db.noteById('n1'))!.body, 'dough');
      expect(bodyField(tester).controller!.text, 'flour');

      gate.complete();
      await tester.pumpAndSettle();

      expect((await harness.db.noteById('n1'))!.body, 'flour');
      expect(bodyField(tester).controller!.text, 'flour');
    },
  );

  appTest('a saved edit does not flicker back to the old text while the note '
      'stream still lags behind the write', (tester) async {
    const lag = Duration(milliseconds: 500);
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes/n1',
      overrides: [
        notesRepositoryProvider.overrideWith(
          (ref) => _LaggingNotesRepository(
            ref.watch(appDatabaseProvider),
            ref.watch(hlcClockProvider),
            ref.watch(idGeneratorProvider),
            lag,
          ),
        ),
      ],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'flour');
    await tester.pump(lag * 2);
    await tester.pumpAndSettle();
    expect(titleField(tester).controller!.text, 'Bread');
    expect(bodyField(tester).controller!.text, 'flour');

    // Every distinct text each field shows, in order.
    final title = titleField(tester).controller!;
    final body = bodyField(tester).controller!;
    final titles = [title.text];
    final bodies = [body.text];
    void recordTitle() {
      if (titles.last != title.text) titles.add(title.text);
    }

    void recordBody() {
      if (bodies.last != body.text) bodies.add(body.text);
    }

    title.addListener(recordTitle);
    body.addListener(recordBody);
    addTearDown(() {
      title.removeListener(recordTitle);
      body.removeListener(recordBody);
    });

    await tester.enterText(find.byKey(const Key('note-title')), 'Milk');
    await tester.enterText(find.byKey(const Key('note-body')), 'dough');
    FocusManager.instance.primaryFocus?.unfocus();
    // Step through the lag frame by frame, so a revert that the stream
    // later papers over is still caught by the listeners above.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect((await harness.db.noteById('n1'))!.title, 'Milk');
    expect((await harness.db.noteById('n1'))!.body, 'dough');
    expect(titles, ['Bread', 'Milk']);
    expect(bodies, ['flour', 'dough']);
    expect(title.text, 'Milk');
    expect(body.text, 'dough');
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

    // Unfocus to nothing -- not into `note-title`, which would leave that
    // field focused and skip `_onFocusChange`'s "nothing has focus" guard
    // entirely, exercising no save-on-unfocus path at all. There is nothing
    // dirty here to save, so the old ('dough') text the field is still
    // showing must not overwrite the sync that landed while it was focused.
    FocusManager.instance.primaryFocus?.unfocus();
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

  appTest(
    'a dirty title flag clears against what was typed, not the normalized '
    'text that was written, so a later sync is not silently skipped',
    (tester) async {
      // Reached from the list, like the popped test above, so the page has
      // something to pop back to.
      final harness = await pumpApp(tester, initialLocation: '/notes');
      await harness.seedList('l1', 'Kitchen');
      // Seeded as something other than "Bread" -- the trimmed text about to
      // be typed -- so the write below actually changes the stored title
      // and takes `_save`'s await path, rather than short-circuiting
      // through its "nothing to write" branch, which clears both flags
      // unconditionally and would never exercise this bug.
      await harness.seedNote('n1', 'l1', title: 'Milk');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();

      // A trailing space: `_save` writes the trimmed title ("Bread"), which
      // never equals the raw field text ("Bread "). Comparing the cleared
      // flag against that normalized value would leave it dirty forever.
      await tester.enterText(find.byKey(const Key('note-title')), 'Bread ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect((await harness.db.noteById('n1'))!.title, 'Bread');

      // A remote sync renames the note while the title field sits
      // unfocused. A still-dirty flag would make `_fill` skip this,
      // leaving the field to show its own stale text instead.
      final stored = (await harness.db.noteById('n1'))!;
      await harness.container
          .read(notesRepositoryProvider)
          .save(stored.copyWith(title: 'Toast'));
      await tester.pumpAndSettle();

      expect((await harness.db.noteById('n1'))!.title, 'Toast');
      expect(titleField(tester).controller!.text, 'Toast');

      // A still-dirty flag would also make `_save` write the field's stale
      // text back over the sync the moment the page pops.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect((await harness.db.noteById('n1'))!.title, 'Toast');
    },
  );

  appTest('clearing the title field then editing the body reverts the title '
      'field to the stored title, not a lingering blank', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-title')), '');
    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // An empty title falls back to the stored one, not a blank write.
    expect((await harness.db.noteById('n1'))!.title, 'Bread');
    expect((await harness.db.noteById('n1'))!.body, 'flour');
    // The field itself must catch up to that fallback, not keep showing
    // the blank text that was typed into it.
    expect(titleField(tester).controller!.text, 'Bread');
  });

  appTest('an unsaved edit is saved when the page is left without a pop, '
      'as a browser back or a deep link does', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    // Well inside the debounce: nothing has been written yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect((await harness.db.noteById('n1'))!.body, 'dough');

    // A URL change, not a pop: `PopScope` never hears of it.
    harness.router.go('/notes');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-body')), findsNothing);
    expect((await harness.db.noteById('n1'))!.body, 'flour');
  });

  appTest('an unsaved edit is saved when the page is torn down while the '
      'body still has focus', (tester) async {
    // No route change and no unfocus -- the page just goes, as it does when
    // the whole tree above it is replaced. Only `dispose` is left to save.
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect((await harness.db.noteById('n1'))!.body, 'flour');
  });

  appTest('an edit whose save failed is retried when the page is left', (
    tester,
  ) async {
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes/n1',
      overrides: [
        notesRepositoryProvider.overrideWith(
          (ref) => _FailingOnceNotesRepository(
            ref.watch(appDatabaseProvider),
            ref.watch(hlcClockProvider),
            ref.watch(idGeneratorProvider),
          ),
        ),
      ],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect((await harness.db.noteById('n1'))!.body, 'dough');

    harness.router.go('/notes');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-body')), findsNothing);
    expect((await harness.db.noteById('n1'))!.body, 'flour');
  });

  appTest('a pin that lands while the body is dirty survives the save', (
    tester,
  ) async {
    // The note stream lags past the debounce, so when the save fires the
    // provider still holds the unpinned note -- the window in which a
    // whole-row write would put the pin back.
    const lag = Duration(seconds: 2);
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes/n1',
      overrides: [
        notesRepositoryProvider.overrideWith(
          (ref) => _LaggingNotesRepository(
            ref.watch(appDatabaseProvider),
            ref.watch(hlcClockProvider),
            ref.watch(idGeneratorProvider),
            lag,
          ),
        ),
      ],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pump(lag * 2);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    await harness.container
        .read(notesRepositoryProvider)
        .setPinned('n1', pinned: true);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(lag * 2);
    await tester.pumpAndSettle();

    final stored = (await harness.db.noteById('n1'))!;
    expect(stored.body, 'flour');
    expect(stored.pinned, isTrue);
  });

  appTest('a save that fails says so and keeps the text', (tester) async {
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes/n1',
      overrides: [
        notesRepositoryProvider.overrideWith(
          (ref) => _FailingNotesRepository(
            ref.watch(appDatabaseProvider),
            ref.watch(hlcClockProvider),
            ref.watch(idGeneratorProvider),
          ),
        ),
      ],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save the note"), findsOneWidget);
    expect(bodyField(tester).controller!.text, 'flour');
    expect((await harness.db.noteById('n1'))!.body, 'dough');
  });

  appTest('a save that fails on back keeps the page open', (tester) async {
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes',
      overrides: [
        notesRepositoryProvider.overrideWith(
          (ref) => _FailingNotesRepository(
            ref.watch(appDatabaseProvider),
            ref.watch(hlcClockProvider),
            ref.watch(idGeneratorProvider),
          ),
        ),
      ],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'dough');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-body')), findsOneWidget);
    expect(bodyField(tester).controller!.text, 'flour');
    expect(find.text("Couldn't save the note"), findsOneWidget);
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
