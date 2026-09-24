import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/make_todo_chip.dart';
import 'package:nemo/l10n/app_localizations.dart';

void main() {
  Future<({List<String> made, List<String> opened})> pumpChip(
    WidgetTester tester,
    TextEditingValue value,
  ) async {
    final controller = TextEditingController.fromValue(value);
    addTearDown(controller.dispose);
    final made = <String>[];
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: Center(
            child: MakeTodoChip(
              controller: controller,
              onMakeTodo: () => made.add('made'),
              onOpenTask: opened.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (made: made, opened: opened);
  }

  testWidgets('a selection offers Make todo, and the tap makes one', (
    tester,
  ) async {
    final calls = await pumpChip(
      tester,
      const TextEditingValue(
        text: 'milk\nbread',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      ),
    );
    expect(find.text('Make todo'), findsOneWidget);
    expect(find.byIcon(Icons.add_task), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-make-todo-chip')));
    await tester.pump();
    expect(calls.made, ['made']);
    expect(calls.opened, isEmpty);
  });

  testWidgets('a cursor on a list line shows nothing, though the toolbar '
      'could make a task of it', (tester) async {
    await pumpChip(
      tester,
      const TextEditingValue(
        text: '- [ ] milk',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    expect(find.byKey(const Key('note-make-todo-chip')), findsNothing);
  });

  testWidgets('a selection with nothing to make shows nothing', (tester) async {
    await pumpChip(
      tester,
      const TextEditingValue(
        text: '- [x] eggs\nmilk',
        selection: TextSelection(baseOffset: 0, extentOffset: 11),
      ),
    );
    expect(find.byKey(const Key('note-make-todo-chip')), findsNothing);
  });

  testWidgets('a cursor on plain text shows nothing', (tester) async {
    await pumpChip(
      tester,
      const TextEditingValue(
        text: 'just some words',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(find.byKey(const Key('note-make-todo-chip')), findsNothing);
    expect(find.text('Make todo'), findsNothing);
  });

  testWidgets('a cursor on a linked line offers the task and opens it', (
    tester,
  ) async {
    final calls = await pumpChip(
      tester,
      const TextEditingValue(
        text: '- milk [→ task](nemo://task/t1)',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(find.text('Open task'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.text('Make todo'), findsNothing);

    await tester.tap(find.byKey(const Key('note-make-todo-chip')));
    await tester.pump();
    expect(calls.opened, ['t1']);
    expect(calls.made, isEmpty);
  });
}
