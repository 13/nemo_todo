import 'package:nemo_core/src/model/task.dart';

/// How a list's tasks are sorted.
///
/// Stored on the list as [wire], so every member of a shared list sees the
/// same order.
enum TaskOrder {
  /// The order someone dragged them into: the sort key.
  manual('manual'),

  /// Earliest due first, undated last.
  dueDate('due'),

  /// High priority first, none last; then by due date.
  priority('priority'),

  /// Alphabetical, ignoring case.
  title('title'),

  /// Newest first.
  added('added');

  TaskOrder(this.wire);

  /// The value stored on the list row and sent over the wire.
  final String wire;

  /// The order [value] names, or [manual] for anything this version does
  /// not know -- a value from a newer one, or none at all.
  static TaskOrder parse(String? value) {
    for (final order in values) {
      if (order.wire == value) return order;
    }
    return manual;
  }
}

/// [tasks] in [order], open ones before done ones.
///
/// Every order breaks its ties on the sort key, so two tasks that compare
/// equal keep the order someone gave them by hand rather than an arbitrary
/// one that could change between two builds of the same list.
List<Task> sortTasks(Iterable<Task> tasks, TaskOrder order) {
  final compare = _comparator(order);
  return [...tasks]..sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final c = compare(a, b);
    return c != 0 ? c : a.sortKey.compareTo(b.sortKey);
  });
}

int Function(Task, Task) _comparator(TaskOrder order) => switch (order) {
  TaskOrder.manual => (a, b) => 0,
  TaskOrder.dueDate => _byDue,
  TaskOrder.priority => (a, b) {
    final c = b.priority.compareTo(a.priority);
    return c != 0 ? c : _byDue(a, b);
  },
  TaskOrder.title => (a, b) => a.title.toLowerCase().compareTo(
    b.title.toLowerCase(),
  ),
  TaskOrder.added => (a, b) => _addedAt(b).compareTo(_addedAt(a)),
};

int _byDue(Task a, Task b) {
  final x = a.dueAt;
  final y = b.dueAt;
  if (x == null || y == null) {
    if (x == y) return 0;
    return x == null ? 1 : -1;
  }
  return x.compareTo(y);
}

/// When [task] was added, or for one from before that was recorded, the
/// wall-clock part of its last-write stamp: the closest thing it has, and
/// never missing. A stamp that cannot be read counts as the oldest.
int _addedAt(Task task) =>
    task.createdAt ??
    (task.updatedAt.length >= 13
        ? int.tryParse(task.updatedAt.substring(0, 13))
        : null) ??
    0;
