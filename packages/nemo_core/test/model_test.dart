import 'dart:convert';

import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  test('Task JSON round trip keeps tags and nullables', () {
    const task = Task(
      id: 't1',
      listId: 'l1',
      title: 'Buy milk',
      tags: ['home', 'food'],
      dueAt: 1725700000000,
      priority: 2,
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    final json = jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>;
    expect(json['list_id'], 'l1');
    expect(json['tags'], ['home', 'food']);
    expect(json['done_at'], isNull);
    expect(Task.fromJson(json), task);
    expect(task.isDeleted, isFalse);
  });

  test('TaskList defaults and isDeleted', () {
    const list = TaskList(
      id: 'l1',
      name: 'Inbox',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    expect(list.color, 0);
    expect(list.icon, 'list');
    expect(list.isDeleted, isFalse);
    expect(list.copyWith(deletedAt: '0000000000002-0000-n').isDeleted, isTrue);
    expect(TaskList.fromJson(list.toJson()), list);
  });

  test('Subtask JSON uses snake_case', () {
    const s = Subtask(
      id: 's',
      taskId: 't',
      title: 'x',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    expect(s.toJson()['task_id'], 't');
    expect(Subtask.fromJson(s.toJson()), s);
    expect(s.isDeleted, isFalse);
  });
}
