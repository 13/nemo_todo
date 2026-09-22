import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../generated/schema.dart';
import '../../support/test_db.dart';

void main() {
  // Each case opens a second database over the verifier's connection.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('every schema version has a snapshot to migrate from', () {
    final db = testDatabase();
    addTearDown(db.close);
    expect(
      File('drift_schemas/drift_schema_v${db.schemaVersion}.json').existsSync(),
      isTrue,
      reason:
          'run: dart run drift_dev schema dump '
          'lib/core/db/app_database.dart drift_schemas/',
    );
  });

  test('migrates a database from every earlier version', () async {
    for (final from in [1, 2, 3, 4]) {
      final verifier = SchemaVerifier(GeneratedHelper());
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, 5);
      await db.close();
    }
  });

  test('the migrated database has the index a fresh one gets', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 5);
    final indexes =
        (await db
                .customSelect(
                  "select name from sqlite_master where type = 'index'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toList();
    expect(indexes, containsAll(['photos_parent', 'notes_list_id']));
    await db.close();
  });

  test('upgrading to photos starts the change log over', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase
      ..execute('insert into kv (key, value) values (?, ?)', [
        KvKeys.cursor,
        '42',
      ])
      ..execute('insert into kv (key, value) values (?, ?)', [
        KvKeys.username,
        'ben',
      ]);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);

    final kv = KvStore(db);
    expect(
      await kv.get(KvKeys.cursor),
      isNull,
      reason:
          'the server skipped photo changes for this device while it ran a '
          'build without photos',
    );
    expect(await kv.get(KvKeys.username), 'ben', reason: 'only the cursor');
    await db.close();
  });

  test('upgrading to notes starts the change log over', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase
      ..execute('insert into kv (key, value) values (?, ?)', [
        KvKeys.cursor,
        '42',
      ])
      ..execute('insert into kv (key, value) values (?, ?)', [
        KvKeys.username,
        'ben',
      ]);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);

    final kv = KvStore(db);
    expect(
      await kv.get(KvKeys.cursor),
      isNull,
      reason:
          'the server skipped note changes for this device while it ran a '
          'build without notes',
    );
    expect(await kv.get(KvKeys.username), 'ben', reason: 'only the cursor');
    await db.close();
  });

  test('upgrading to task work fields starts the change log over', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase
      ..execute('insert into kv (key, value) values (?, ?)', [
        KvKeys.cursor,
        '42',
      ])
      ..execute('insert into kv (key, value) values (?, ?)', [
        KvKeys.username,
        'ben',
      ]);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);

    final kv = KvStore(db);
    expect(
      await kv.get(KvKeys.cursor),
      isNull,
      reason:
          'a device running the build before this migration decoded task '
          'rows through a Task.fromJson that dropped solution/time/cost '
          'and advanced its cursor past them',
    );
    expect(await kv.get(KvKeys.username), 'ben', reason: 'only the cursor');
    await db.close();
  });

  test('a photo keeps its parent across the v4 migration', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      'insert into photos (id, task_id, sha256, byte_size, width, height, '
      'sort_key, updated_at) values (?, ?, ?, ?, ?, ?, ?, ?)',
      ['p1', 't1', 'a' * 64, 10, 2, 1, 'V', '0000000000001-0000-n'],
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);

    final row = await db.photoById('p1');

    expect(row!.parentKind, PhotoParent.task);
    expect(row.parentId, 't1');
    await db.close();
  });

  test('a task survives the v5 migration unrecorded', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
      'insert into tasks (id, list_id, title, tags, sort_key, updated_at) '
      'values (?, ?, ?, ?, ?, ?)',
      ['t1', 'l1', 'Fix the tap', '[]', 'V', '0000000000001-0000-n'],
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);

    final row = await db.taskById('t1');

    expect(row!.solution, '');
    expect(row.timeSpentMinutes, isNull);
    expect(row.costMinor, isNull);
    await db.close();
  });
}
