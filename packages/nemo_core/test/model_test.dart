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

  test('a task reads its repeat rule and ignores one it cannot read', () {
    const task = Task(
      id: 't1',
      listId: 'l1',
      title: 'Water the plants',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
      repeat: 'weekly',
    );
    expect(task.repeatRule, Repeats.weekly);
    expect(task.copyWith(repeat: 'every:3x').repeatRule, isNull);
    expect(task.copyWith(repeat: null).repeatRule, isNull);
  });

  test('a task carries what it took, and what it costs to omit', () {
    const task = Task(
      id: 't1',
      listId: 'l1',
      title: 'Fix the tap',
      solution: 'New washer, 12 mm',
      timeSpentMinutes: 90,
      costMinor: 1250,
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );

    final json = jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>;

    expect(json['solution'], 'New washer, 12 mm');
    expect(json['time_spent_minutes'], 90);
    expect(json['cost_minor'], 1250);
    expect(Task.fromJson(json), task);
  });

  test('a task from before these fields reads as empty and unrecorded', () {
    final json = {
      'id': 't1',
      'list_id': 'l1',
      'title': 'Fix the tap',
      'sort_key': 'V',
      'updated_at': '0000000000001-0000-n',
    };

    final task = Task.fromJson(json);

    expect(task.solution, '');
    expect(
      task.timeSpentMinutes,
      isNull,
      reason: 'nobody recorded a time, which is not the same as zero',
    );
    expect(task.costMinor, isNull);
  });
}
