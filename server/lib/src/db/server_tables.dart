import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get tokenHash => text()();
  TextColumn get userId => text()();
  IntColumn get expiresAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {tokenHash};
}

class ListMembers extends Table {
  TextColumn get listId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text()();

  @override
  Set<Column<Object>> get primaryKey => {listId, userId};
}

/// One live row per changed entity row. `seq` only ever grows, so a client
/// that remembers the last `seq` it saw can ask for everything after it.
@TableIndex(name: 'sync_log_list_id', columns: {#listId})
@TableIndex(name: 'sync_log_for_user_id', columns: {#forUserId})
class SyncLog extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get rowId => text()();
  TextColumn get listId => text()();
  TextColumn get forUserId => text().nullable()();
  TextColumn get op => text()();
}
