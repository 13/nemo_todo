import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';

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
    for (final from in [1, 2]) {
      final verifier = SchemaVerifier(GeneratedHelper());
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    }
  });

  test('the migrated database has the index a fresh one gets', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    final indexes =
        (await db
                .customSelect(
                  "select name from sqlite_master where type = 'index'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toList();
    expect(indexes, contains('photos_task_id'));
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
    await verifier.migrateAndValidate(db, 3);

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
}
