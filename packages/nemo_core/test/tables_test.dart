import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

import 'support/test_database.dart';

void main() {
  late TestDatabase db;

  setUp(() => db = TestDatabase());
  tearDown(() => db.close());

  test('rows round trip through the shared tables', () async {
    const list = TaskList(
      id: 'l',
      name: 'Inbox',
      sortKey: 'V',
      isInbox: true,
      updatedAt: '0000000000001-0000-n',
    );
    const task = Task(
      id: 't',
      listId: 'l',
      title: 'x',
      tags: ['a', 'b'],
      dueAt: 5,
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    const sub = Subtask(
      id: 's',
      taskId: 't',
      title: 'y',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    await db.into(db.lists).insert(list.toInsertable());
    await db.into(db.tasks).insert(task.toInsertable());
    await db.into(db.subtasks).insert(sub.toInsertable());
    expect(await db.select(db.lists).getSingle(), list);
    expect(await db.select(db.tasks).getSingle(), task);
    expect(await db.select(db.subtasks).getSingle(), sub);
  });

  test('sql column names are snake_case and indexes exist', () async {
    final sql = await db
        .customSelect("select sql from sqlite_master where name = 'tasks'")
        .getSingle();
    expect(sql.read<String>('sql'), contains('list_id'));
    expect(sql.read<String>('sql'), contains('due_has_time'));
    final indexes = await db
        .customSelect("select name from sqlite_master where type = 'index'")
        .get();
    expect(
      indexes.map((r) => r.read<String>('name')),
      containsAll(['tasks_list_id', 'subtasks_task_id']),
    );
  });
}
