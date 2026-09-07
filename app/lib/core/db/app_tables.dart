import 'package:drift/drift.dart';

/// Rows changed locally and not yet accepted by the server.
/// `enqueuedUpdatedAt` is the row's HLC at enqueue time; an ack only removes
/// the entry when the row has not changed since the push.
@DataClassName('OutboxEntry')
class Outbox extends Table {
  TextColumn get entity => text()();
  TextColumn get rowId => text()();
  TextColumn get enqueuedUpdatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {entity, rowId};
}

/// What the server told us about a list's sharing, kept for offline display.
@DataClassName('ListMetaRow')
class ListMeta extends Table {
  TextColumn get listId => text()();
  TextColumn get myRole => text().nullable()();
  TextColumn get membersJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {listId};
}

/// Small settings and sync bookkeeping.
@DataClassName('KvRow')
class Kv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
