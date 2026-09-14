import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late TasksRepository tasks;
  late SubtasksRepository subtasks;
  late AchievementsRepository repo;
  late String inbox;

  setUp(() async {
    db = testDatabase();
    final clock = testClock();
    final ids = sequentialIds();
    inbox = (await ListsRepository(db, clock, ids).ensureInbox()).id;
    tasks = TasksRepository(
      db,
      clock,
      ids,
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    subtasks = SubtasksRepository(db, clock, ids);
    repo = AchievementsRepository(db, now: () => testNow);
  });
  tearDown(() => db.close());

  test('stats count done tasks and their checklists', () async {
    final a = await tasks.create(listId: inbox, title: 'A');
    for (var i = 0; i < 5; i++) {
      await subtasks.add(a.id, 'step $i');
    }
    final b = await tasks.create(listId: inbox, title: 'B');
    await tasks.setDone(a.id, done: true);
    await tasks.setDone(b.id, done: true);
    await tasks.delete(b.id);

    final s = await repo.stats();
    expect(s.totalDone, 1);
    expect(s.maxSubtasksOnDoneTask, 5);
    expect(s.currentStreak, 1);
  });

  test('Today is clear once nothing due today or earlier is open', () async {
    await tasks.create(listId: inbox, title: 'Someday');
    expect(await repo.todayIsClear(), isTrue, reason: 'undated is not Today');
    final due = await tasks.create(
      listId: inbox,
      title: 'Due',
      dueAt: dayStartMs(testNow),
    );
    await tasks.create(
      listId: inbox,
      title: 'Tomorrow',
      dueAt: dayStartMsFrom(testNow, 1),
    );
    expect(await repo.todayIsClear(), isFalse);
    await tasks.setDone(due.id, done: true);
    expect(await repo.todayIsClear(), isTrue);
  });

  test('Today is not clear while a late task on a long day is open', () async {
    // 25 October 2026 lasts 25 hours in Europe; run with TZ=Europe/Berlin.
    final sunday = DateTime(2026, 10, 25, 12);
    await tasks.create(
      listId: inbox,
      title: 'Late',
      dueAt: composeDue(sunday, hour: 23, minute: 30),
      dueHasTime: true,
    );
    final onSunday = AchievementsRepository(db, now: () => sunday);
    expect(await onSunday.todayIsClear(), isFalse);
  });

  test('a cleared day is counted once', () async {
    await repo.recordClearedDay();
    await repo.recordClearedDay();
    expect((await repo.stats()).clearedDays, 1);
  });

  test('a cleared day is counted once when two taps race', () async {
    await Future.wait([repo.recordClearedDay(), repo.recordClearedDay()]);
    expect((await repo.stats()).clearedDays, 1);
  });

  test('the celebrated set starts unset and grows', () async {
    expect(await repo.seen(), isNull);
    await repo.markSeen(['first_done']);
    await repo.markSeen(['done_10', 'first_done']);
    expect(await repo.seen(), {'first_done', 'done_10'});
  });

  test('a damaged celebrated set reads as unset', () async {
    await KvStore(db).set(KvKeys.achievementsSeen, 'not json');
    expect(await repo.seen(), isNull);
  });

  test('stats follow the database', () async {
    final a = await tasks.create(listId: inbox, title: 'A');
    final totals = repo.watchStats().map((s) => s.totalDone);
    final reached = expectLater(totals, emitsThrough(1));
    await tasks.setDone(a.id, done: true);
    await reached;
  });
}
