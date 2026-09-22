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
    // Wide enough that, once the shell's rail and its divider are
    // subtracted, the notes grid still has >= 900 of its own width to work
    // with, but below the 1200 split breakpoint where a second, task-detail
    // pane would also eat into that width. Passed straight to pumpApp: it
    // sets its own physical size, so calling _tallSurface first would only
    // have it overwritten.
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes',
      size: const Size(1100, 2000),
    );
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
