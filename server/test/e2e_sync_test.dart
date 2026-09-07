import 'dart:convert';

import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

import 'support/test_server.dart';

/// A stand-in for one installation of the app: its own clock, its own
/// cursor, its own copy of the rows, and the same merge rule the app uses.
class Device {
  Device(this._server, this.name, this.token);

  final TestServer _server;
  final String name;
  final String token;
  late final HlcClock clock = HlcClock(node: name);

  final lists = <String, TaskList>{};
  final tasks = <String, Task>{};
  final subtasks = <String, Subtask>{};
  final outbox = <String, SyncChange>{};
  var cursor = 0;
  Map<String, List<ListMember>> members = const {};
  final rejected = <RejectedChange>[];

  void put(SyncChange change) =>
      outbox['${change.entity.name}:${change.rowId}'] = change;

  TaskList newList(String id, String name) {
    final row = TaskList(
      id: id,
      name: name,
      sortKey: SortKey.first(),
      updatedAt: clock.now().toString(),
    );
    lists[id] = row;
    put(SyncChange.list(row));
    return row;
  }

  Task newTask(String id, String listId, String title) {
    final row = Task(
      id: id,
      listId: listId,
      title: title,
      sortKey: SortKey.first(),
      updatedAt: clock.now().toString(),
    );
    tasks[id] = row;
    put(SyncChange.task(row));
    return row;
  }

  Subtask newSubtask(String id, String taskId, String title) {
    final row = Subtask(
      id: id,
      taskId: taskId,
      title: title,
      sortKey: SortKey.first(),
      updatedAt: clock.now().toString(),
    );
    subtasks[id] = row;
    put(SyncChange.subtask(row));
    return row;
  }

  void editTask(String id, {String? title, String? listId}) {
    final row = tasks[id]!.copyWith(
      title: title ?? tasks[id]!.title,
      listId: listId ?? tasks[id]!.listId,
      updatedAt: clock.now().toString(),
    );
    tasks[id] = row;
    put(SyncChange.task(row));
  }

  /// One full round: push what is queued, apply what comes back, repeat
  /// while the server has more to send.
  Future<void> sync() async {
    var hasMore = true;
    var pushed = false;
    while (hasMore) {
      final changes = pushed ? <SyncChange>[] : outbox.values.toList();
      final response = await _post(
        SyncRequest(cursor: cursor, changes: changes),
      );
      pushed = true;
      for (final change in changes) {
        outbox.remove('${change.entity.name}:${change.rowId}');
      }
      rejected.addAll(response.rejected);
      for (final change in response.changes) {
        _apply(change);
      }
      members = response.members;
      clock.receive(Hlc.parse(response.serverHlc));
      cursor = response.cursor;
      hasMore = response.hasMore;
    }
  }

  void _apply(SyncChange change) {
    switch (change) {
      case SyncChangeList(:final row):
        if (incomingWins(lists[row.id], row)) lists[row.id] = row;
      case SyncChangeTask(:final row):
        if (incomingWins(tasks[row.id], row)) tasks[row.id] = row;
      case SyncChangeSubtask(:final row):
        if (incomingWins(subtasks[row.id], row)) subtasks[row.id] = row;
      case SyncChangeRevoke(:final target, :final id):
        switch (target) {
          case SyncEntity.list:
            lists.remove(id);
            tasks.removeWhere((_, t) => t.listId == id);
          case SyncEntity.task:
            tasks.remove(id);
            subtasks.removeWhere((_, s) => s.taskId == id);
          case SyncEntity.subtask:
            subtasks.remove(id);
        }
    }
  }

  Future<SyncResponse> _post(SyncRequest request) async {
    final response = await _server.post(
      '/api/v1/sync',
      request.toJson(),
      token: token,
    );
    if (response.statusCode != 200) {
      throw StateError('sync failed: ${response.statusCode} ${response.body}');
    }
    return SyncResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

void main() {
  late TestServer server;

  setUp(() async => server = await TestServer.start());
  tearDown(() => server.close());

  test('two devices of one account converge', () async {
    final token = await server.signup('ben');
    final phone = Device(server, 'phone', token);
    final laptop = Device(server, 'laptop', token);

    phone
      ..newList('l1', 'Groceries')
      ..newTask('t1', 'l1', 'Milk');
    await phone.sync();
    await laptop.sync();

    expect(laptop.lists['l1']!.name, 'Groceries');
    expect(laptop.tasks['t1']!.title, 'Milk');
    expect(laptop.lists['l1']!.ownerId, isNotNull);

    // Both edit the same task while apart. The edit with the higher stamp
    // survives on both devices; which one that is depends on the clocks,
    // and within a single millisecond on the node id, so the guarantee
    // under test is that they agree on the same winner.
    phone.editTask('t1', title: 'Oat milk');
    laptop.editTask('t1', title: 'Almond milk');
    final winner =
        phone.tasks['t1']!.updatedAt.compareTo(laptop.tasks['t1']!.updatedAt) >
            0
        ? 'Oat milk'
        : 'Almond milk';
    await phone.sync();
    await laptop.sync();
    await phone.sync();

    expect(laptop.tasks['t1']!.title, winner);
    expect(phone.tasks['t1']!.title, winner);
    expect(phone.outbox, isEmpty);
    expect(laptop.outbox, isEmpty);
  });

  test(
    'a shared list reaches the other account and can be taken back',
    () async {
      final benToken = await server.signup('ben');
      final annaToken = await server.signup('anna');
      final ben = Device(server, 'ben-phone', benToken);
      final anna = Device(server, 'anna-phone', annaToken);

      ben
        ..newList('l1', 'Trip')
        ..newTask('t1', 'l1', 'Book hotel')
        ..newSubtask('s1', 't1', 'Compare prices');
      await ben.sync();
      await anna.sync();
      expect(anna.lists, isEmpty, reason: 'nothing is shared yet');

      final shared = await server.post('/api/v1/lists/l1/members', {
        'username': 'anna',
        'role': 'editor',
      }, token: benToken);
      expect(shared.statusCode, 200, reason: shared.body);

      await anna.sync();
      expect(anna.lists['l1']!.name, 'Trip');
      expect(anna.tasks['t1']!.title, 'Book hotel');
      expect(anna.subtasks['s1']!.title, 'Compare prices');
      expect(anna.members['l1']!.map((m) => '${m.username}:${m.role.name}'), [
        'ben:owner',
        'anna:editor',
      ]);

      // An editor may change tasks, and the owner sees it.
      anna.editTask('t1', title: 'Book the hotel');
      await anna.sync();
      await ben.sync();
      expect(ben.tasks['t1']!.title, 'Book the hotel');

      // Removing her takes the rows away and stops her writes.
      final removed = await server.delete(
        '/api/v1/lists/l1/members/anna',
        token: benToken,
      );
      expect(removed.statusCode, 200);
      await anna.sync();
      expect(anna.lists, isEmpty);
      expect(anna.tasks, isEmpty);
      expect(anna.subtasks, isEmpty);

      anna.tasks['t1'] = ben.tasks['t1']!;
      anna.editTask('t1', title: 'Sneaky edit');
      await anna.sync();
      expect(anna.rejected.single.reason, 'forbidden');
      await ben.sync();
      expect(ben.tasks['t1']!.title, 'Book the hotel');
    },
  );

  test(
    'a task moved out of a shared list disappears for the other member',
    () async {
      final benToken = await server.signup('ben');
      final annaToken = await server.signup('anna');
      final ben = Device(server, 'ben-phone', benToken);
      final anna = Device(server, 'anna-phone', annaToken);

      ben
        ..newList('shared', 'Shared')
        ..newList('private', 'Private')
        ..newTask('t1', 'shared', 'Secret plan')
        ..newSubtask('s1', 't1', 'Step one');
      await ben.sync();
      await server.post('/api/v1/lists/shared/members', {
        'username': 'anna',
        'role': 'editor',
      }, token: benToken);
      await anna.sync();
      expect(anna.tasks['t1'], isNotNull);
      expect(anna.subtasks['s1'], isNotNull);

      ben.editTask('t1', listId: 'private');
      await ben.sync();
      await anna.sync();

      expect(anna.tasks, isEmpty, reason: 'the task left her list');
      expect(anna.subtasks, isEmpty);
      expect(anna.lists.keys, ['shared']);
      expect(ben.tasks['t1']!.listId, 'private');
    },
  );

  test('a client whose clock runs fast is refused', () async {
    final token = await server.signup('ben');
    final device = Device(server, 'fast', token);
    device.newList('l1', 'Fine');
    await device.sync();

    // Two hours ahead of the server: beyond the one-hour tolerance.
    final ahead = HlcClock(
      node: 'fast',
      now: () => DateTime.now().add(const Duration(hours: 2)),
    );
    device.put(
      SyncChange.task(
        Task(
          id: 't1',
          listId: 'l1',
          title: 'From the future',
          sortKey: 'V',
          updatedAt: ahead.now().toString(),
        ),
      ),
    );
    await device.sync();
    expect(device.rejected.single.reason, 'clock_skew');
    expect(device.tasks['t1'], isNull);
  });

  test('a large list arrives in pages', () async {
    final token = await server.signup('ben');
    final phone = Device(server, 'phone', token);
    final laptop = Device(server, 'laptop', token);
    phone.newList('l1', 'Big');
    for (var i = 0; i < 550; i++) {
      phone.newTask('t$i', 'l1', 'Task $i');
    }
    await phone.sync();
    await laptop.sync();
    expect(laptop.tasks, hasLength(550));
    expect(laptop.cursor, 551);
  });
}
