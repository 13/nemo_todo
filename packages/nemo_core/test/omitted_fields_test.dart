import 'dart:convert';

import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

/// A list as an app from before sorting pushes it: no `task_order` key.
Map<String, dynamic> _oldList() => {
  'id': 'l',
  'name': 'Groceries',
  'sort_key': 'V',
  'updated_at': '0000000000002-0000-old',
  'color': 3,
  'icon': 'list',
  'owner_id': null,
  'is_inbox': false,
  'deleted_at': null,
};

/// A task as an app from before the work fields and `created_at` pushes it.
Map<String, dynamic> _oldTask() => {
  'id': 't',
  'list_id': 'l',
  'title': 'Fix the tap',
  'sort_key': 'V',
  'updated_at': '0000000000002-0000-old',
  'notes': '',
  'done': false,
  'done_at': null,
  'due_at': null,
  'due_has_time': false,
  'remind': false,
  'priority': 0,
  'tags': <String>[],
  'repeat': null,
  'deleted_at': null,
};

SyncChange _decode(String type, Map<String, dynamic> row) =>
    SyncRequest.fromJson({
      'cursor': 0,
      'changes': [
        {'type': type, 'row': row},
      ],
    }).changes.single;

void main() {
  group('decoding a pushed row', () {
    test('names the list keys an older app left out', () {
      final change = _decode('list', _oldList()) as SyncChangeList;
      expect(change.omitted, {'task_order'});
      expect(change.row.taskOrder, 'manual');
    });

    test('names the task keys an older app left out', () {
      final change = _decode('task', _oldTask()) as SyncChangeTask;
      expect(change.omitted, {
        'solution',
        'time_spent_minutes',
        'cost_minor',
        'created_at',
      });
    });

    test('a key sent as null is not left out', () {
      final change = _decode('task', {
        ..._oldTask(),
        'solution': '',
        'time_spent_minutes': null,
        'cost_minor': null,
        'created_at': null,
      }) as SyncChangeTask;
      expect(change.omitted, isEmpty);
    });

    test('this version leaves nothing out, Manual included', () {
      const list = TaskList(
        id: 'l',
        name: 'n',
        sortKey: 'V',
        updatedAt: '0000000000001-0000-n',
      );
      const task = Task(
        id: 't',
        listId: 'l',
        title: 'x',
        sortKey: 'V',
        updatedAt: '0000000000001-0000-n',
      );
      final json = jsonDecode(
        jsonEncode(
          const SyncRequest(
            cursor: 0,
            changes: [SyncChange.list(list), SyncChange.task(task)],
          ).toJson(),
        ),
      ) as Map<String, dynamic>;
      final rows = [
        for (final c in json['changes'] as List<dynamic>)
          (c as Map<String, dynamic>)['row'] as Map<String, dynamic>,
      ];
      expect(rows.first, containsPair('task_order', 'manual'));
      expect(rows.last, containsPair('created_at', null));

      final back = SyncRequest.fromJson(json);
      expect((back.changes.first as SyncChangeList).omitted, isEmpty);
      expect((back.changes.last as SyncChangeTask).omitted, isEmpty);
    });

    test('the omitted keys never go back out on the wire', () {
      final change = _decode('list', _oldList());
      expect(change.toJson().keys, unorderedEquals(['type', 'row']));
      expect(
        (change.toJson()['row'] as Map<String, dynamic>)['task_order'],
        'manual',
      );
    });
  });

  group('keepOmitted', () {
    const stored = TaskList(
      id: 'l',
      name: 'Shopping',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-new',
      taskOrder: 'priority',
      ownerId: 'u',
    );

    test('keeps the stored value of a field the push left out', () {
      final change = _decode('list', _oldList()) as SyncChangeList;
      final merged = keepOmitted(change.row, stored, change.omitted);
      expect(merged.taskOrder, 'priority');
      expect(merged.name, 'Groceries', reason: 'what it did send wins');
      expect(merged.color, 3);
      expect(merged.updatedAt, '0000000000002-0000-old');
    });

    test("keeps a task's work fields and when it was added", () {
      const storedTask = Task(
        id: 't',
        listId: 'l',
        title: 'Fix the tap',
        sortKey: 'V',
        updatedAt: '0000000000001-0000-new',
        solution: 'New washer',
        timeSpentMinutes: 30,
        costMinor: 450,
        createdAt: 1234,
      );
      final change =
          _decode('task', {..._oldTask(), 'done': true}) as SyncChangeTask;
      final merged = keepOmitted(change.row, storedTask, change.omitted);
      expect(merged.done, isTrue);
      expect(merged.solution, 'New washer');
      expect(merged.timeSpentMinutes, 30);
      expect(merged.costMinor, 450);
      expect(merged.createdAt, 1234);
    });

    test('a field sent as null is cleared, not kept', () {
      const storedTask = Task(
        id: 't',
        listId: 'l',
        title: 'x',
        sortKey: 'V',
        updatedAt: '0000000000001-0000-new',
        timeSpentMinutes: 30,
      );
      final change = _decode('task', {
        ..._oldTask(),
        'solution': '',
        'time_spent_minutes': null,
        'cost_minor': null,
        'created_at': null,
      }) as SyncChangeTask;
      final merged = keepOmitted(change.row, storedTask, change.omitted);
      expect(merged.timeSpentMinutes, isNull);
    });

    test('with nothing stored, the row is taken as sent', () {
      final change = _decode('list', _oldList()) as SyncChangeList;
      expect(keepOmitted(change.row, null, change.omitted), change.row);
    });
  });
}
