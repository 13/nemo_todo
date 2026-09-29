import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';

void main() {
  // Each case opens a second database over the verifier's connection.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('every schema version has a snapshot to migrate from', () {
    final version = ServerDatabase.memory().schemaVersion;
    expect(
      File('drift_schemas/drift_schema_v$version.json').existsSync(),
      isTrue,
      reason:
          'run: dart run drift_dev schema dump '
          'lib/src/db/server_database.dart drift_schemas/',
    );
  });

  test('migrates a database from every earlier version', () async {
    for (final from in [1, 2, 3, 4, 5, 6]) {
      final verifier = SchemaVerifier(GeneratedHelper());
      final connection = await verifier.startAt(from);
      final db = ServerDatabase(connection);
      await verifier.migrateAndValidate(db, 7);
      await db.close();
    }
  });

  test('the migrated database has the indexes a fresh one gets', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = ServerDatabase(connection);
    await verifier.migrateAndValidate(db, 7);
    final indexes =
        (await db
                .customSelect(
                  "select name from sqlite_master where type = 'index'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toList();
    expect(
      indexes,
      containsAll([
        'list_members_user_id',
        'sync_log_row',
        'photos_parent',
        'notes_list_id',
        'rate_limit_hits_client_key',
      ]),
    );
    await db.close();
  });

  test('a photo keeps its parent across the v5 migration', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
      'insert into photos (id, task_id, sha256, byte_size, width, height, '
      'sort_key, updated_at) values (?, ?, ?, ?, ?, ?, ?, ?)',
      ['p1', 't1', 'a' * 64, 10, 2, 1, 'V', '0000000000001-0000-n'],
    );
    final db = ServerDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 7);

    final row = await db.photoById('p1');

    expect(row!.parentKind, PhotoParent.task);
    expect(row.parentId, 't1');
    await db.close();
  });

  test('a task survives the v6 migration unrecorded', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase.execute(
      'insert into tasks (id, list_id, title, tags, sort_key, updated_at) '
      'values (?, ?, ?, ?, ?, ?)',
      ['t1', 'l1', 'Fix the tap', '[]', 'V', '0000000000001-0000-n'],
    );
    final db = ServerDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 7);

    final row = await db.taskById('t1');

    expect(row!.solution, '');
    expect(row.timeSpentMinutes, isNull);
    expect(row.costMinor, isNull);
    await db.close();
  });

  test('a list and a task survive the v7 migration unsorted', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(6);
    schema.rawDatabase
      ..execute(
        'insert into lists (id, name, sort_key, updated_at) '
        'values (?, ?, ?, ?)',
        ['l1', 'Shop', 'V', '0000000000001-0000-n'],
      )
      ..execute(
        'insert into tasks (id, list_id, title, tags, sort_key, updated_at) '
        'values (?, ?, ?, ?, ?, ?)',
        ['t1', 'l1', 'Milk', '[]', 'V', '0000000000001-0000-n'],
      );
    final db = ServerDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 7);

    expect((await db.listById('l1'))!.order, TaskOrder.manual);
    expect((await db.taskById('t1'))!.createdAt, isNull);
    await db.close();
  });
}
