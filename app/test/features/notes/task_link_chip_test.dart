import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/task_link_chip.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';

void main() {
  appTest('the chip follows the task and opens it', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await app.seedTask('t1', 'l1', title: 'Buy milk');
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      app.wrap(const Scaffold(body: TaskLinkChip(taskId: 't1'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt), findsOneWidget);

    await app.container.read(tasksRepositoryProvider).setDone('t1', done: true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await app.container.read(tasksRepositoryProvider).delete('t1');
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);
  });

  testWidgets('a task still loading shows as open, not deleted', (
    tester,
  ) async {
    final pending = StreamController<Task?>();
    addTearDown(pending.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskByIdProvider('t1').overrideWith((ref) => pending.stream),
        ],
        child: const MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: TaskLinkChip(taskId: 't1')),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.task_alt), findsOneWidget);
    expect(find.text('Task deleted'), findsNothing);

    pending.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);
  });

  testWidgets('a task whose stream errors shows as open, with the link text', (
    tester,
  ) async {
    final failing = StreamController<Task?>();
    addTearDown(failing.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskByIdProvider('t1').overrideWith((ref) => failing.stream),
        ],
        child: const MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: TaskLinkChip(taskId: 't1')),
        ),
      ),
    );
    await tester.pump();

    failing.addError(StateError('watch failed'));
    await tester.pump();
    expect(find.byIcon(Icons.task_alt), findsOneWidget);
    expect(find.text('Task deleted'), findsNothing);
    expect(find.text('→ task'), findsOneWidget);
  });
}
