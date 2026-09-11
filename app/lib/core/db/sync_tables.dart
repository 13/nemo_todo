// The synced tables. The server defines the identical three tables: drift's
// generator cannot analyse table classes that live in another package, so
// they cannot be shared through nemo_core. The row classes, and therefore
// the column names and types, are shared: drift refuses to generate a
// database whose columns do not match the row class constructor.
import 'package:drift/drift.dart';
import 'package:nemo_core/nemo_core.dart';

@UseRowClass(TaskList, generateInsertable: true)
class Lists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0))();
  TextColumn get icon => text().withDefault(const Constant('list'))();
  TextColumn get sortKey => text()();
  TextColumn get ownerId => text().nullable()();
  BoolColumn get isInbox => boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'tasks_list_id', columns: {#listId})
@UseRowClass(Task, generateInsertable: true)
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get doneAt => integer().nullable()();
  IntColumn get dueAt => integer().nullable()();
  BoolColumn get dueHasTime => boolean().withDefault(const Constant(false))();
  BoolColumn get remind => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get tags => text().map(const StringListConverter())();
  TextColumn get repeat => text().nullable()();
  TextColumn get sortKey => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'subtasks_task_id', columns: {#taskId})
@UseRowClass(Subtask, generateInsertable: true)
class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  TextColumn get sortKey => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
