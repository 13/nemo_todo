import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nemo_core/nemo_core.dart';

part 'test_database.g.dart';

/// Minimal database over the shared tables, used only by tests.
@DriftDatabase(tables: [Lists, Tasks, Subtasks])
class TestDatabase extends _$TestDatabase {
  TestDatabase() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
