import 'dart:io';

import 'package:drift/drift.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:sqlite3/sqlite3.dart';
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

  test('the lookups on every sync are index-backed', () async {
    Future<String> plan(String sql, List<Variable<Object>> args) async {
      final rows = await db
          .customSelect('explain query plan $sql', variables: args)
          .get();
      return rows.map((r) => r.read<String>('detail')).join(' | ');
    }

    // rolesOf() runs on every sync request; the (list_id, user_id) primary
    // key cannot serve a lookup that only knows the user.
    expect(
      await plan('select * from list_members where user_id = ?', [
        const Variable('u'),
      ]),
      contains('list_members_user_id'),
    );

    // logUpsert() deletes by row before re-inserting, once per pushed row.
    expect(
      await plan(
        'select * from sync_log where entity = ? and row_id = ? and op = ?',
        [
          const Variable('task'),
          const Variable('t1'),
          const Variable('upsert'),
        ],
      ),
      contains('sync_log_row'),
    );
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

  test('backupTo writes a copy that stands on its own', () async {
    final dir = Directory.systemTemp.createTempSync('nemo-backup');
    addTearDown(() => dir.deleteSync(recursive: true));
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u1',
            username: 'ben',
            passwordHash: 'hash',
            createdAt: 1,
          ),
        );

    final path = '${dir.path}/nemo.db';
    await db.backupTo(path);
    expect(File(path).existsSync(), isTrue);

    // Read back with plain sqlite3 rather than another drift database:
    // the point of the copy is that it is a database on its own terms.
    final restored = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(restored.close);
    expect(
      restored.select('select username from users').single['username'],
      'ben',
    );
  });

  test('backupTo refuses to overwrite an existing file', () async {
    final dir = Directory.systemTemp.createTempSync('nemo-backup');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/nemo.db';
    File(path).writeAsStringSync('do not lose me');

    await expectLater(db.backupTo(path), throwsA(isA<Object>()));
    expect(File(path).readAsStringSync(), 'do not lose me');
  });
}
