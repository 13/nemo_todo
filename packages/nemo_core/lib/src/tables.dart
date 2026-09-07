import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nemo_core/src/model/subtask.dart';
import 'package:nemo_core/src/model/task.dart';
import 'package:nemo_core/src/model/task_list.dart';

/// Stores a list of strings as a JSON array in a text column.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

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
