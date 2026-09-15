import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late TasksRepository tasks;
  late AchievementsRepository repo;
  late CelebrationController controller;
  late String inbox;
  late List<CelebrationEvent> events;
  var celebrate = true;
  var announce = true;

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
    repo = AchievementsRepository(db, now: () => testNow);
    celebrate = true;
    announce = true;
    controller = CelebrationController(
      repo,
      now: () => testNow,
      celebrate: () => celebrate,
      showAchievements: () => announce,
    );
    events = [];
    controller.events.listen(events.add);
    await controller.backfill();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  Future<Task> add(String title, {bool dueToday = false}) => tasks.create(
    listId: inbox,
    title: title,
    dueAt: dueToday ? dayStartMs(testNow) : null,
  );

  /// Ticks [task] off the way a tap does.
  Future<void> tick(Task task) async {
    await tasks.setDone(task.id, done: true);
    await controller.onCompleted(task);
    await pumpEventQueue();
  }

  List<String> unlockedIds(CelebrationEvent e) => [
    for (final a in (e as AchievementsUnlocked).achievements) a.id,
  ];

  test('the first completion unlocks the first achievement', () async {
    await tick(await add('A'));
    expect(events, hasLength(1));
    expect(unlockedIds(events.single), ['first_done']);
  });

  test('a completion that unlocks nothing is a tick', () async {
    await tick(await add('A'));
    await tick(await add('B'));
    expect(events.last, isA<TickCelebration>());
  });

  test('finishing what is due today clears the day', () async {
    await tick(await add('Someday'));
    final b = await add('B', dueToday: true);
    final c = await add('C', dueToday: true);
    await tick(b);
    expect(events.last, isA<TickCelebration>(), reason: 'C is still open');
    await tick(c);
    expect(unlockedIds(events.last), ['cleared_today']);
    await tick(await add('D', dueToday: true));
    expect(events.last, isA<DayClearedCelebration>());
    expect((await repo.stats()).clearedDays, 1, reason: 'one day, once');
  });

  test('an achievement is celebrated once', () async {
    final a = await add('A');
    await tick(a);
    await tasks.setDone(a.id, done: false);
    await tick(a);
    expect(events, hasLength(2));
    expect(events.last, isA<TickCelebration>());
  });

  test('with celebrations off only unlocks are announced', () async {
    celebrate = false;
    await tick(await add('A'));
    await tick(await add('B'));
    expect(events, hasLength(1));
    expect(events.single, isA<AchievementsUnlocked>());
  });

  test('with everything off nothing is emitted but progress is kept', () async {
    celebrate = false;
    announce = false;
    await tick(await add('A'));
    expect(events, isEmpty);
    expect(await repo.seen(), contains('first_done'));
  });

  test('what sync brought is recorded quietly, not claimed later', () async {
    for (var i = 0; i < 10; i++) {
      final t = await add('Synced $i');
      await tasks.setDone(t.id, done: true);
    }
    await controller.backfill();
    await pumpEventQueue();
    expect(events, isEmpty);
    await tick(await add('Mine'));
    expect(events.single, isA<TickCelebration>());
  });

  test('a damaged store never gets in the way of completing', () async {
    await KvStore(db).set(KvKeys.achievementsSeen, 'not json');
    await tick(await add('A'));
    expect(events.single, isA<TickCelebration>());
    expect(await repo.seen(), {'first_done'});
  });

  test(
    'a backfill asked for during a tap does not swallow its unlock',
    () async {
      final a = await add('A');
      Future<void>? backfill;
      await controller.onCompleted(
        a,
        write: () async {
          await tasks.setDone(a.id, done: true);
          // A sync finishing right after the write asks for a backfill.
          backfill = controller.backfill();
        },
      );
      await backfill;
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(unlockedIds(events.single), ['first_done']);
    },
  );
}
