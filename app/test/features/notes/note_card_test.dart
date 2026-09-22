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
