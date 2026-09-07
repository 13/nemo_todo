import 'package:nemo_core/nemo_core.dart';

/// A fixed wall clock so tests never trip the skew guard.
final fixedNow = DateTime.fromMillisecondsSinceEpoch(1700000000000);

HlcClock deviceClock(String node) => HlcClock(node: node, now: () => fixedNow);

/// A second device whose clock runs one second ahead, so its edits win.
HlcClock laterClock(String node) =>
    HlcClock(node: node, now: () => fixedNow.add(const Duration(seconds: 1)));

TaskList list(String id, HlcClock clock, {String name = 'List'}) => TaskList(
  id: id,
  name: name,
  sortKey: 'V',
  updatedAt: clock.now().toString(),
);

Task task(String id, String listId, HlcClock clock, {String title = 'Task'}) =>
    Task(
      id: id,
      listId: listId,
      title: title,
      sortKey: 'V',
      updatedAt: clock.now().toString(),
    );

Subtask subtask(String id, String taskId, HlcClock clock) => Subtask(
  id: id,
  taskId: taskId,
  title: 'Sub',
  sortKey: 'V',
  updatedAt: clock.now().toString(),
);
