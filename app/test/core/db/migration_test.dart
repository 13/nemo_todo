import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/test_db.dart';

void main() {
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
}
