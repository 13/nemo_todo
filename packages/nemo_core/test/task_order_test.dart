import 'dart:convert';

import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

Task _t(
  String id, {
  String sortKey = 'V',
  String title = 'x',
  int? dueAt,
  int priority = 0,
  int? createdAt,
  String updatedAt = '0000000000001-0000-n',
  bool done = false,
}) => Task(
  id: id,
  listId: 'l',
  title: title,
  sortKey: sortKey,
  dueAt: dueAt,
  priority: priority,
  createdAt: createdAt,
  updatedAt: updatedAt,
  done: done,
);

List<String> _ids(List<Task> tasks, TaskOrder order) =>
    sortTasks(tasks, order).map((t) => t.id).toList();

void main() {
  group('TaskOrder', () {
    test('reads every value it writes', () {
      for (final order in TaskOrder.values) {
        expect(TaskOrder.parse(order.wire), order);
      }
    });

    test('reads anything else as manual', () {
      expect(TaskOrder.parse(null), TaskOrder.manual);
      expect(TaskOrder.parse(''), TaskOrder.manual);
      expect(TaskOrder.parse('by-mood'), TaskOrder.manual);
    });
  });

  group('sortTasks', () {
    test('manual is the sort key', () {
      final tasks = [_t('b', sortKey: 'W'), _t('a', sortKey: 'U')];
      expect(_ids(tasks, TaskOrder.manual), ['a', 'b']);
    });

    test('open tasks come before done ones whatever the order', () {
      final tasks = [
        _t('done', title: 'a', done: true),
        _t('open', title: 'z'),
      ];
      for (final order in TaskOrder.values) {
        expect(_ids(tasks, order), ['open', 'done'], reason: order.name);
      }
    });

    test('due date: earliest first, undated last, ties by sort key', () {
      final tasks = [
        _t('none', sortKey: 'A'),
        _t('late', dueAt: 300),
        _t('early2', dueAt: 100, sortKey: 'W'),
        _t('early1', dueAt: 100, sortKey: 'U'),
      ];
      expect(_ids(tasks, TaskOrder.dueDate), [
        'early1',
        'early2',
        'late',
        'none',
      ]);
    });

    test('priority: high first, then by due date, then sort key', () {
      final tasks = [
        _t('none', sortKey: 'A'),
        _t('low', priority: 1),
        _t('high-undated', priority: 3, sortKey: 'A'),
        _t('high-dated', priority: 3, dueAt: 5, sortKey: 'Z'),
        _t('medium', priority: 2),
      ];
      expect(_ids(tasks, TaskOrder.priority), [
        'high-dated',
        'high-undated',
        'medium',
        'low',
        'none',
      ]);
    });

    test('title: case-insensitive, ties by sort key', () {
      final tasks = [
        _t('b', title: 'banana'),
        _t('A2', title: 'Apple', sortKey: 'W'),
        _t('a1', title: 'apple', sortKey: 'U'),
        _t('c', title: 'Cherry'),
      ];
      expect(_ids(tasks, TaskOrder.title), ['a1', 'A2', 'b', 'c']);
    });

    test('date added: newest first, falling back to the last write', () {
      final tasks = [
        _t('old', createdAt: 1000),
        _t('new', createdAt: 3000),
        // No createdAt: from before the field, sorted by its stamp's time.
        _t('legacy', updatedAt: '0000000002000-0000-n'),
        _t('tie-b', createdAt: 500, sortKey: 'W'),
        _t('tie-a', createdAt: 500, sortKey: 'U'),
      ];
      expect(_ids(tasks, TaskOrder.added), [
        'new',
        'legacy',
        'old',
        'tie-a',
        'tie-b',
      ]);
    });

    test('a stamp it cannot read sorts as the oldest', () {
      final tasks = [
        _t('odd', updatedAt: 'garbage'),
        _t('known', createdAt: 1),
      ];
      expect(_ids(tasks, TaskOrder.added), ['known', 'odd']);
    });
  });

  group('the fields on the wire', () {
    test('a list carries its order', () {
      const list = TaskList(
        id: 'l1',
        name: 'Shop',
        sortKey: 'V',
        updatedAt: '0000000000001-0000-n',
        taskOrder: 'priority',
      );
      final json =
          jsonDecode(jsonEncode(list.toJson())) as Map<String, dynamic>;
      expect(json['task_order'], 'priority');
      expect(TaskList.fromJson(json), list);
      expect(list.order, TaskOrder.priority);
    });

    test('a list from before the field is manual', () {
      final list = TaskList.fromJson({
        'id': 'l1',
        'name': 'Shop',
        'sort_key': 'V',
        'updated_at': '0000000000001-0000-n',
      });
      expect(list.taskOrder, 'manual');
      expect(list.order, TaskOrder.manual);
    });

    test('an order from a newer version travels through intact', () {
      const list = TaskList(
        id: 'l1',
        name: 'Shop',
        sortKey: 'V',
        updatedAt: '0000000000001-0000-n',
        taskOrder: 'by-mood',
      );
      expect(TaskList.fromJson(list.toJson()).taskOrder, 'by-mood');
      expect(list.order, TaskOrder.manual);
    });

    test('a task carries when it was added, and older ones have none', () {
      final task = _t('t', createdAt: 1234);
      final json =
          jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>;
      expect(json['created_at'], 1234);
      expect(Task.fromJson(json), task);

      json.remove('created_at');
      expect(Task.fromJson(json).createdAt, isNull);
    });
  });
}
