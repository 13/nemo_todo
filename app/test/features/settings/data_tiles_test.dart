import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/settings/ui/data_tiles.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

class _FakeFiles implements DataFiles {
  final saved = <String, Uint8List>{};
  Uint8List? toOpen;

  @override
  Future<bool> save(String name, Uint8List bytes) async {
    saved[name] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> open() async => toOpen;
}

void main() {
  late _FakeFiles files;

  setUp(() => files = _FakeFiles());

  Future<TestApp> pump(WidgetTester tester) => pumpApp(
    tester,
    initialLocation: Routes.settings,
    overrides: [dataFilesProvider.overrideWithValue(files)],
    seed: (db, inbox) async {
      await TasksRepository(
        db,
        testClock('s'),
        sequentialIds('t'),
        reminders: const NoopReminderScheduler(),
        now: () => testNow,
      ).create(listId: inbox.id, title: 'Water the plants');
    },
  );

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  appTest('export saves a dated file holding the tasks', (tester) async {
    await pump(tester);
    await tap(tester, 'export-data');

    final bytes = files.saved['nemo-2026-09-07.json'];
    expect(bytes, isNotNull);
    expect(utf8.decode(bytes!), contains('Water the plants'));
    expect(find.text('Tasks exported.'), findsOneWidget);
  });

  appTest('import restores a deleted task and refuses other files', (
    tester,
  ) async {
    final app = await pump(tester);
    await tap(tester, 'export-data');
    files.toOpen = files.saved.values.single;

    await tap(tester, 'import-data');
    expect(find.text('Nothing new to import.'), findsOneWidget);

    final task = (await app.db.select(app.db.tasks).get()).single;
    await (app.db.update(
      app.db.tasks,
    )..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(deletedAt: Value(testClock('x').now().toString())),
    );
    await tap(tester, 'import-data');
    expect(find.text('1 item imported.'), findsOneWidget);
    expect((await app.db.select(app.db.tasks).get()).single.deletedAt, isNull);

    files.toOpen = Uint8List.fromList(utf8.encode('{"hello": "world"}'));
    await tap(tester, 'import-data');
    expect(find.text('That file is not a nemo export.'), findsOneWidget);
  });
}
