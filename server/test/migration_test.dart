import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
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
    for (final from in [1, 2]) {
      final verifier = SchemaVerifier(GeneratedHelper());
      final connection = await verifier.startAt(from);
      final db = ServerDatabase(connection);
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    }
  });

  test('the migrated database has the indexes a fresh one gets', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = ServerDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    final indexes =
        (await db
                .customSelect(
                  "select name from sqlite_master where type = 'index'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toList();
    expect(indexes, containsAll(['list_members_user_id', 'sync_log_row']));
    await db.close();
  });
}
