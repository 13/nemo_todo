# Notes Keep Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the notes screen as a Google Keep-style masonry grid of cards with Pinned / Others sections.

**Architecture:** A new `NoteCard` widget draws one note as an outlined card. `NotesScreen` swaps its grouped `ListView` for a `CustomScrollView` of two `SliverMasonryGrid`s (pinned, then the rest), each note sorted by `updatedAt` descending, with the column count picked from the available width. Nothing below the UI changes.

**Tech Stack:** Flutter 3.47.2 (via fvm), Riverpod, go_router, `flutter_staggered_grid_view`, gen-l10n.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-22-notes-keep-grid-design.md`.
- Flutter is not on PATH: prefix commands with `export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH`. Run them from `app/`.
- UI only: no change to `Note`, the database, sync or export.
- `NoteTile` and the search screen stay unchanged.
- Card key stays `note-tile-<id>`.
- Columns: 2 below 600 px of available width, 3 from 600 px, 4 from 900 px. Grid inside `MaxWidth(maxWidth: 1200)`.
- Card body preview: markdown source, max 10 lines; title max 2 lines, omitted when empty; `notePreviewEmpty` when the body is blank.
- Strings: `notesPinned` / `notesOthers` = en "Pinned"/"Others", de "Angeheftet"/"Andere", it "Fissate"/"Altre".
- Run at most one `flutter test` process at a time, with `--concurrency=2` for directories (shared machine, OOM risk).
- Commits end with the session's `Co-Authored-By` / `Claude-Session` trailer lines. The pre-commit hook regenerates generated sources and fails if they differ: commit regenerated files with their sources.

---

### Task 1: `NoteCard` widget

**Files:**
- Create: `app/lib/features/notes/ui/note_card.dart`
- Test: `app/test/features/notes/note_card_test.dart`

**Interfaces:**
- Consumes: `Note` (`nemo_core`), `L.notePreviewEmpty`, `Routes.note(String id)`.
- Produces: `NoteCard({required Note note, String? listName, Key? key})`. Its root widget carries `Key('note-tile-${note.id}')`; the pin icon carries `Key('note-card-pin-${note.id}')`.

- [ ] **Step 1: Write the failing test**

`app/test/features/notes/note_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/note_card.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

Note _note({String title = 'Bread', String body = '', bool pinned = false}) =>
    Note(
      id: 'n1',
      listId: 'l1',
      title: title,
      body: body,
      pinned: pinned,
      sortKey: 'V',
      updatedAt: '0000000000001-0000-a',
    );

Future<void> _pump(WidgetTester tester, Widget card) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: Scaffold(body: SizedBox(width: 200, child: card)),
  ),
);

void main() {
  testWidgets('shows title, body preview and list name', (tester) async {
    await _pump(
      tester,
      NoteCard(note: _note(body: '500 g flour'), listName: 'Kitchen'),
    );

    expect(find.byKey(const Key('note-tile-n1')), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('500 g flour'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.byKey(const Key('note-card-pin-n1')), findsNothing);
  });

  testWidgets('a blank body shows the empty-note placeholder', (tester) async {
    await _pump(tester, NoteCard(note: _note(body: '  ')));

    expect(find.text('Empty note'), findsOneWidget);
  });

  testWidgets('an empty title is left out', (tester) async {
    await _pump(tester, NoteCard(note: _note(title: '', body: 'only body')));

    expect(find.text('only body'), findsOneWidget);
    // Only the body text: no empty title Text above it.
    expect(
      find.descendant(
        of: find.byKey(const Key('note-tile-n1')),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a pinned note shows the pin', (tester) async {
    await _pump(tester, NoteCard(note: _note(pinned: true)));

    expect(find.byKey(const Key('note-card-pin-n1')), findsOneWidget);
  });

  testWidgets('a long body is cut at ten lines', (tester) async {
    final body = List.generate(30, (i) => 'line $i').join('\n');
    await _pump(tester, NoteCard(note: _note(body: body)));

    final text = tester.widget<Text>(find.textContaining('line 0'));
    expect(text.maxLines, 10);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/note_card_test.dart`
Expected: FAIL, compile error `Target of URI doesn't exist: 'package:nemo/features/notes/ui/note_card.dart'`.

- [ ] **Step 3: Write the implementation**

`app/lib/features/notes/ui/note_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// A note as a card in the notes grid, the way Google Keep shows one: the
/// title, a long preview of the body, the list it belongs to and a pin when
/// it is pinned. Tapping opens the note.
///
/// Keyed `note-tile-<id>`, the key the notes screen's rows had before they
/// were cards, so finders written against the rows still find the card.
class NoteCard extends StatelessWidget {
  const NoteCard({required this.note, this.listName, super.key});

  final Note note;

  /// The name of the note's list, or null when that list is gone.
  final String? listName;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final title = note.title.trim();
    // Markdown source, not rendered, for the reason NoteTile gives: a
    // heading or an image would otherwise set the size of the card.
    final preview = note.body.trim();
    return Card.outlined(
      key: Key('note-tile-${note.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.note(note.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty || note.pinned) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: title.isEmpty
                          ? const SizedBox.shrink()
                          : Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    if (note.pinned)
                      Icon(
                        Icons.push_pin,
                        key: Key('note-card-pin-${note.id}'),
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                preview.isEmpty ? l.notePreviewEmpty : preview,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (listName case final name?) ...[
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/note_card_test.dart`
Expected: `All tests passed!` (5 tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/notes test/features/notes`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notes/ui/note_card.dart app/test/features/notes/note_card_test.dart
git commit -m "feat(app): add a Keep-style note card"
```

---

### Task 2: Masonry notes screen with Pinned / Others

**Files:**
- Modify: `app/pubspec.yaml` (dependency), root `pubspec.lock`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb` (+ regenerated `app_localizations*.dart`)
- Modify: `app/lib/features/notes/ui/notes_screen.dart` (whole body)
- Modify: `app/test/support/pump_app.dart:84-100` (`seedNote` gains `updatedAt`)
- Test: `app/test/features/notes/notes_screen_test.dart`

**Interfaces:**
- Consumes: `NoteCard({required Note note, String? listName})` from Task 1; `allNotesProvider`, `allListsProvider`.
- Produces: `L.notesPinned`, `L.notesOthers`; label keys `Key('notes-pinned-label')`, `Key('notes-others-label')`; `TestApp.seedNote(..., String? updatedAt)`.

- [ ] **Step 1: Add the dependency**

Run (from `app/`): `flutter pub add flutter_staggered_grid_view`
Expected: `app/pubspec.yaml` gains `flutter_staggered_grid_view: ^0.7.0` (or the current version) and the root `pubspec.lock` updates.

- [ ] **Step 2: Add the strings**

In `app/lib/l10n/app_en.arb`, after the `"notesEmpty"` entry (line 551):

```json
  "notesPinned": "Pinned",
  "notesOthers": "Others",
```

In `app/lib/l10n/app_de.arb`, after `"notesEmpty"` (line 276):

```json
  "notesPinned": "Angeheftet",
  "notesOthers": "Andere",
```

In `app/lib/l10n/app_it.arb`, after `"notesEmpty"` (line 276):

```json
  "notesPinned": "Fissate",
  "notesOthers": "Altre",
```

If `app_en.arb` gives its neighbours `@notesEmpty`-style description entries, add matching `"@notesPinned"` / `"@notesOthers"` entries: "Heading over the pinned notes in the notes grid." / "Heading over the unpinned notes, shown only when some notes are pinned."

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` gain `notesPinned` and `notesOthers`.

- [ ] **Step 3: Let `seedNote` set `updatedAt`**

In `app/test/support/pump_app.dart`, replace `seedNote` with:

```dart
  Future<void> seedNote(
    String id,
    String listId, {
    required String title,
    String body = '',
    bool pinned = false,
    String? updatedAt,
  }) => db.upsertNote(
    Note(
      id: id,
      listId: listId,
      title: title,
      body: body,
      pinned: pinned,
      sortKey: 'V',
      updatedAt: updatedAt ?? testClock('a').now().toString(),
    ),
  );
```

- [ ] **Step 4: Write the failing tests**

Replace `app/test/features/notes/notes_screen_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/notes_screen.dart';

import '../../support/pump_app.dart';

/// A surface tall enough that the lazy grid builds every card.
void _tallSurface(WidgetTester tester, {double width = 400}) {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the notes destination shows notes as cards with their list', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '500 g flour');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-tile-n1')), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('500 g flour'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.byType(NotesScreen), findsOneWidget);
  });

  testWidgets('with no notes the empty state says so', (tester) async {
    await pumpApp(tester, initialLocation: '/notes');
    await tester.pumpAndSettle();

    expect(find.textContaining('No notes yet'), findsOneWidget);
  });

  testWidgets('tapping a note opens it', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-title')), findsOneWidget);
  });

  testWidgets('pinned notes sit under Pinned, above Others', (tester) async {
    _tallSurface(tester);
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Loose');
    await harness.seedNote('n2', 'l1', title: 'Stuck', pinned: true);
    await tester.pumpAndSettle();

    final pinnedLabel = find.byKey(const Key('notes-pinned-label'));
    final othersLabel = find.byKey(const Key('notes-others-label'));
    expect(pinnedLabel, findsOneWidget);
    expect(othersLabel, findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Others'), findsOneWidget);

    final pinnedTop = tester.getTopLeft(find.byKey(const Key('note-tile-n2')));
    final looseTop = tester.getTopLeft(find.byKey(const Key('note-tile-n1')));
    final othersTop = tester.getTopLeft(othersLabel);
    expect(tester.getTopLeft(pinnedLabel).dy, lessThan(pinnedTop.dy));
    expect(pinnedTop.dy, lessThan(othersTop.dy));
    expect(othersTop.dy, lessThan(looseTop.dy));
  });

  testWidgets('with nothing pinned there are no section labels', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Loose');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notes-pinned-label')), findsNothing);
    expect(find.byKey(const Key('notes-others-label')), findsNothing);
  });

  testWidgets('with everything pinned only Pinned shows', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Stuck', pinned: true);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notes-pinned-label')), findsOneWidget);
    expect(find.byKey(const Key('notes-others-label')), findsNothing);
  });

  testWidgets('notes run newest first, across lists', (tester) async {
    _tallSurface(tester);
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedList('l2', 'Work');
    await harness.seedNote(
      'old',
      'l1',
      title: 'Old',
      updatedAt: '0000000000001-0000-a',
    );
    await harness.seedNote(
      'mid',
      'l2',
      title: 'Mid',
      updatedAt: '0000000000002-0000-a',
    );
    await harness.seedNote(
      'new',
      'l1',
      title: 'New',
      updatedAt: '0000000000003-0000-a',
    );
    await tester.pumpAndSettle();

    // Masonry fills the shortest column first: two columns, equal-height
    // cards, so the order reads left, right, then left again below.
    final newest = tester.getTopLeft(find.byKey(const Key('note-tile-new')));
    final middle = tester.getTopLeft(find.byKey(const Key('note-tile-mid')));
    final oldest = tester.getTopLeft(find.byKey(const Key('note-tile-old')));
    expect(newest.dy, middle.dy);
    expect(newest.dx, lessThan(middle.dx));
    expect(oldest.dy, greaterThan(newest.dy));
  });

  testWidgets('every note gets a card', (tester) async {
    _tallSurface(tester);
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    for (var i = 0; i < 6; i++) {
      await harness.seedNote('n$i', 'l1', title: 'Note $i');
    }
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('note-tile-n$i')), findsOneWidget);
    }
  });

  testWidgets('a wide screen shows four columns', (tester) async {
    _tallSurface(tester, width: 1200);
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    for (var i = 0; i < 4; i++) {
      await harness.seedNote('n$i', 'l1', title: 'Note $i');
    }
    await tester.pumpAndSettle();

    final tops = {
      for (var i = 0; i < 4; i++)
        tester.getTopLeft(find.byKey(Key('note-tile-n$i'))).dy,
    };
    expect(tops, hasLength(1), reason: 'all four cards share one row');
  });
}
```

Note on the ordering test: all three cards have one-line titles and blank bodies ("Empty note"), and the same list label length class, so they are equal height; if the card heights differ (for example `Kitchen` vs `Work` wrapping), shorten the list names rather than loosening the assertions.

Note on the wide-screen test: the app shell may put a navigation rail beside the screen at 1200 px. The grid is capped at 1200 and the rail takes some of it, so the available width must still be at least 900 px: 1200 minus a rail of about 80 px leaves enough. If it does not (the test sees two rows), raise the surface width to 1400.

- [ ] **Step 5: Run tests to verify they fail**

Run: `flutter test test/features/notes/notes_screen_test.dart`
Expected: FAIL. The first test fails on `note-tile-n1` not found; the label, order and column tests fail too.

- [ ] **Step 6: Rewrite the screen**

Replace `app/lib/features/notes/ui/notes_screen.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/note_card.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Every note there is, as a grid of cards the way Google Keep shows them:
/// pinned notes first, under their own heading, then the rest.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // Newest first. A note's sortKey only orders it within its own list,
    // and this grid mixes every list.
    final notes = [...?ref.watch(allNotesProvider).value]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final lists = ref.watch(allListsProvider).value ?? const <TaskList>[];
    final listNames = {for (final list in lists) list.id: list.name};
    final pinned = [for (final note in notes) if (note.pinned) note];
    final others = [for (final note in notes) if (!note.pinned) note];

    return Scaffold(
      appBar: AppBar(title: Text(l.navNotes)),
      floatingActionButton: lists.isEmpty
          ? null
          : FloatingActionButton(
              key: const Key('note-create'),
              onPressed: () async {
                // Inbox by default, the way QuickAddBar picks a list for a
                // new task when none is preselected.
                final listId =
                    lists.where((x) => x.isInbox).firstOrNull?.id ??
                    lists.first.id;
                final note = await ref
                    .read(notesRepositoryProvider)
                    .create(listId: listId, title: l.noteNewTitle);
                if (context.mounted) {
                  unawaited(context.push(Routes.note(note.id)));
                }
              },
              child: const Icon(Icons.add),
            ),
      body: notes.isEmpty
          ? EmptyState(
              icon: Icons.sticky_note_2_outlined,
              message: l.notesEmpty,
            )
          // Wider than the app's usual 720: a grid of cards uses the room
          // a column of text rows could not.
          : MaxWidth(
              maxWidth: 1200,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = switch (constraints.maxWidth) {
                    >= 900 => 4,
                    >= 600 => 3,
                    _ => 2,
                  };
                  Widget grid(List<Note> held) => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childCount: held.length,
                      itemBuilder: (context, i) => NoteCard(
                        note: held[i],
                        listName: listNames[held[i].listId],
                      ),
                    ),
                  );
                  Widget label(String text, Key key) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        text,
                        key: key,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  );
                  return CustomScrollView(
                    slivers: [
                      // Keep's rule: the headings appear only once there is
                      // a pinned note to set apart from the rest.
                      if (pinned.isNotEmpty) ...[
                        label(l.notesPinned, const Key('notes-pinned-label')),
                        grid(pinned),
                        if (others.isNotEmpty)
                          label(
                            l.notesOthers,
                            const Key('notes-others-label'),
                          ),
                      ] else
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (others.isNotEmpty) grid(others),
                      // Room to scroll the last cards out from under the FAB.
                      const SliverToBoxAdapter(child: SizedBox(height: 88)),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/notes/notes_screen_test.dart`
Expected: `All tests passed!` (9 tests). If the ordering or wide-screen test fails, apply the notes under Step 4 before changing the screen.

- [ ] **Step 8: Run the notes and search tests, and analyze**

Run: `flutter test --concurrency=2 test/features/notes test/features/tasks`
Expected: all pass. Check the reported count covers both directories. The search screen still uses `NoteTile`, so its tests must be untouched and passing.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add app/pubspec.yaml pubspec.lock app/lib/l10n app/lib/features/notes/ui/notes_screen.dart app/test/support/pump_app.dart app/test/features/notes/notes_screen_test.dart
git commit -m "feat(app): show notes as a Keep-style grid with Pinned and Others"
```

---

### Task 3: Look at it in a browser

**Files:** none changed unless something looks wrong.

- [ ] **Step 1: Build and serve the web app**

Follow the project's web browser-check routine: `flutter build web --no-web-resources-cdn` from `app/`, serve `build/web` locally.

- [ ] **Step 2: Check phone and desktop widths**

With Playwright, create a few notes (some pinned, one with a long body, one with an empty title) and screenshot at 390×844 and 1280×800. Confirm: 2 columns on phone, 4 on desktop; Pinned / Others labels; varied card heights; list name on each card; the FAB does not cover the last card at the bottom of the scroll.

- [ ] **Step 3: Fix and commit anything off**

Any fix goes with a test in `notes_screen_test.dart` or `note_card_test.dart`, then:

```bash
git commit -am "fix(app): <what looked wrong in the notes grid>"
```
