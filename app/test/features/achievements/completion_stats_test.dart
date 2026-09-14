import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo_core/nemo_core.dart';

final now = DateTime(2026, 9, 7, 10);

Task done(
  String id,
  DateTime at, {
  DateTime? due,
  bool hasTime = false,
  bool deleted = false,
}) => Task(
  id: id,
  listId: 'l',
  title: id,
  sortKey: 'a',
  updatedAt: '0',
  done: true,
  doneAt: at.millisecondsSinceEpoch,
  dueAt: due?.millisecondsSinceEpoch,
  dueHasTime: hasTime,
  deletedAt: deleted ? '1' : null,
);

Task open(String id) =>
    Task(id: id, listId: 'l', title: id, sortKey: 'a', updatedAt: '0');

Subtask sub(String id, String taskId, {bool deleted = false}) => Subtask(
  id: id,
  taskId: taskId,
  title: id,
  sortKey: 'a',
  updatedAt: '0',
  deletedAt: deleted ? '1' : null,
);

CompletionStats of(
  List<Task> tasks, {
  List<Subtask> subtasks = const [],
  DateTime? at,
  int cleared = 0,
}) => CompletionStats.from(
  tasks: tasks,
  subtasks: subtasks,
  now: at ?? now,
  clearedDays: cleared,
);

void main() {
  test('nothing done is all zeros', () {
    final s = of([open('a')]);
    expect(s.totalDone, 0);
    expect(s.onTimeDone, 0);
    expect(s.currentStreak, 0);
    expect(s.bestStreak, 0);
    expect(s.maxSubtasksOnDoneTask, 0);
  });

  test('counts done tasks and ignores open and deleted ones', () {
    final s = of([done('a', now), done('b', now, deleted: true), open('c')]);
    expect(s.totalDone, 1);
  });

  test('on time is up to the due time, or anywhere in the due day', () {
    final s = of([
      // Due on the 7th without a time, done that morning: on time.
      done('a', DateTime(2026, 9, 7, 10), due: DateTime(2026, 9, 7)),
      // Due on the 7th without a time, done just after midnight: late.
      done('b', DateTime(2026, 9, 8, 0, 30), due: DateTime(2026, 9, 7)),
      // Due at 09:00, done at 10:00: late.
      done('c', now, due: DateTime(2026, 9, 7, 9), hasTime: true),
      // Due at 09:00, done at 08:59: on time.
      done(
        'd',
        DateTime(2026, 9, 7, 8, 59),
        due: DateTime(2026, 9, 7, 9),
        hasTime: true,
      ),
      // No due date never counts as on time.
      done('e', now),
    ]);
    expect(s.onTimeDone, 2);
  });

  test('the due day lasts until midnight when the clocks go back', () {
    // 25 October 2026 lasts 25 hours in Europe; run with TZ=Europe/Berlin.
    final s = of([
      done('a', DateTime(2026, 10, 25, 23, 30), due: DateTime(2026, 10, 25)),
      done('b', DateTime(2026, 10, 26, 0, 30), due: DateTime(2026, 10, 25)),
    ], at: DateTime(2026, 10, 26, 12));
    expect(s.onTimeDone, 1);
  });

  test('streak counts consecutive local days ending today', () {
    final s = of([
      done('a', DateTime(2026, 9, 5, 23, 30)),
      done('b', DateTime(2026, 9, 6, 0, 30)),
      done('c', DateTime(2026, 9, 7, 8)),
    ]);
    expect(s.currentStreak, 3);
    expect(s.bestStreak, 3);
  });

  test('a streak survives a day with nothing done yet', () {
    final s = of([
      done('a', DateTime(2026, 9, 5, 12)),
      done('b', DateTime(2026, 9, 6, 12)),
    ]);
    expect(s.currentStreak, 2);
  });

  test('a gap ends the current streak but not the best one', () {
    final s = of([
      for (var d = 1; d <= 4; d++) done('a$d', DateTime(2026, 9, d, 12)),
      done('b', DateTime(2026, 9, 7, 9)),
    ]);
    expect(s.currentStreak, 1);
    expect(s.bestStreak, 4);
  });

  test('a streak crosses a daylight saving change', () {
    // Europe moves its clocks on 29 March 2026. Calendar days, not 24-hour
    // spans, keep this a three-day streak in any time zone; run the file
    // with TZ=Europe/Berlin to exercise the change itself.
    final s = of([
      done('a', DateTime(2026, 3, 28, 23, 30)),
      done('b', DateTime(2026, 3, 29, 23, 30)),
      done('c', DateTime(2026, 3, 30, 0, 30)),
    ], at: DateTime(2026, 3, 30, 12));
    expect(s.currentStreak, 3);
  });

  test('largest checklist counts live subtasks of done tasks only', () {
    final s = of(
      [done('a', now), open('b')],
      subtasks: [
        for (var i = 0; i < 5; i++) sub('a$i', 'a'),
        sub('ax', 'a', deleted: true),
        for (var i = 0; i < 7; i++) sub('b$i', 'b'),
      ],
    );
    expect(s.maxSubtasksOnDoneTask, 5);
  });

  test('cleared days are passed through', () {
    expect(of([], cleared: 3).clearedDays, 3);
  });
}
