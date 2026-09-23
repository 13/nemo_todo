import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/make_todo_sheet.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';

import '../../support/pump_app.dart';

void main() {
  Future<MakeTodoResult?> open(
    WidgetTester tester,
    TestApp app, {
    List<TodoCandidate> candidates = const [],
    WholeNoteTodo? wholeNote,
    Future<void> Function()? interact,
  }) async {
    MakeTodoResult? result;
    await tester.pumpWidget(
      app.wrap(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showMakeTodoSheet(
                context,
                candidates: candidates,
                wholeNote: wholeNote,
                listId: 'l1',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await interact?.call();
    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();
    return result;
  }

  appTest('one candidate: editable title, list and priority', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();

    final r = await open(
      tester,
      app,
      candidates: const [TodoCandidate(title: 'milk', anchor: 4)],
      interact: () async {
        await tester.enterText(find.byKey(const Key('todo-title')), 'oat milk');
        await tester.tap(find.byKey(const Key('todo-priority-3')));
        await tester.pump();
      },
    );
    expect(r!.tasks.single.title, 'oat milk');
    expect(r.listId, 'l1');
    expect(r.priority, 3);
    expect(r.dueAt, isNull);
  });

  appTest('several lines: one task per line by default', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();

    final r = await open(
      tester,
      app,
      candidates: const [
        TodoCandidate(title: 'milk', anchor: 4),
        TodoCandidate(title: 'bread', anchor: 10),
      ],
    );
    expect(r!.tasks.map((t) => t.title), ['milk', 'bread']);
    expect(r.tasks.every((t) => t.subtasks.isEmpty), isTrue);
  });

  appTest('several lines as one task with subtasks', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();

    final r = await open(
      tester,
      app,
      candidates: const [
        TodoCandidate(title: 'shop', anchor: 4),
        TodoCandidate(title: 'milk', anchor: 10),
        TodoCandidate(title: 'bread', anchor: 16),
      ],
      interact: () async {
        await tester.tap(find.byKey(const Key('todo-shape-subtasks')));
        await tester.pump();
      },
    );
    expect(r!.tasks.single.title, 'shop');
    expect(r.tasks.single.subtasks, ['milk', 'bread']);
  });

  appTest('whole note: checklist becomes subtasks unless switched off', (
    tester,
  ) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();
    final whole = wholeNoteTodo('Shop', 'Sunday\n- [ ] milk');

    final on = await open(tester, app, wholeNote: whole);
    expect(on!.tasks.single.title, 'Shop');
    expect(on.tasks.single.subtasks, ['milk']);
    expect(on.tasks.single.notes, 'Sunday');

    final off = await open(
      tester,
      app,
      wholeNote: whole,
      interact: () async {
        await tester.tap(find.byKey(const Key('todo-checklist-subtasks')));
        await tester.pump();
      },
    );
    expect(off!.tasks.single.subtasks, isEmpty);
    expect(off.tasks.single.notes, 'Sunday\n- [ ] milk');
  });
}
