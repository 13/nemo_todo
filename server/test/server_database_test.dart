import 'package:drift/drift.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  late ServerDatabase db;

  setUp(() => db = ServerDatabase.memory());
  tearDown(() => db.close());

  test('creates the shared and the server-only tables', () async {
    final rows = await db
        .customSelect("select name from sqlite_master where type = 'table'")
        .get();
    expect(
      rows.map((r) => r.read<String>('name')),
      containsAll([
        'lists',
        'tasks',
        'subtasks',
        'users',
        'sessions',
        'list_members',
        'sync_log',
      ]),
    );
  });

  test('stores shared rows through the nemo_core row classes', () async {
    const list = TaskList(
      id: 'l',
      name: 'Inbox',
      sortKey: 'V',
      ownerId: 'u',
      updatedAt: '0000000000001-0000-n',
    );
    await db.into(db.lists).insert(list.toInsertable());
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u',
            username: 'ben',
            passwordHash: 'x',
            createdAt: 0,
          ),
        );
    await db
        .into(db.listMembers)
        .insert(
          ListMembersCompanion.insert(listId: 'l', userId: 'u', role: 'owner'),
        );
    expect(await db.select(db.lists).getSingle(), list);
    expect((await db.select(db.listMembers).getSingle()).role, 'owner');
  });

  test('sync_log seq auto increments', () async {
    for (final id in ['a', 'b']) {
      await db
          .into(db.syncLog)
          .insert(
            SyncLogCompanion.insert(
              entity: 'task',
              rowId: id,
              listId: 'l',
              op: 'upsert',
              forUserId: const Value(null),
            ),
          );
    }
    final seqs = (await db.select(db.syncLog).get()).map((r) => r.seq);
    expect(seqs, [1, 2]);
  });
}
