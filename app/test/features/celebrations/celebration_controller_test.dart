import 'dart:async';

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

/// Holds the first `seen()` read after [arm] until [release], so a test can
/// put a backfill exactly between a tap's write and its check.
///
/// The gate the next `seen()` call should take ([_armed]) is tracked apart
/// from the one an in-flight call is actually waiting on ([_pending]):
/// consuming [_armed] has to happen before the await so a second, racing
/// caller is not also held, but [release] still needs a live reference
/// after that, or it would have nothing left to complete.
class _GatedRepository extends AchievementsRepository {
  // The parameter is private in the super constructor (`this._db`), so it
  // cannot share its name across libraries.
  // ignore: matching_super_parameters
  _GatedRepository(super.db, {super.now});

  Completer<void>? _armed;
  Completer<void>? _pending;

  void arm() => _armed = Completer<void>();
  void release() => _pending?.complete();

  @override
  Future<Set<String>?> seen() async {
    final gate = _armed;
    if (gate != null) {
      _armed = null;
      _pending = gate;
      await gate.future;
    }
    return await super.seen();
  }
}

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
      expect(backfill, isNotNull);
      await backfill;
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(unlockedIds(events.single), ['first_done']);
    },
  );

  test(
    'a backfill landing between a tap and its check waits its turn',
    () async {
      final gated = _GatedRepository(db, now: () => testNow);
      final gatedController = CelebrationController(
        gated,
        now: () => testNow,
        celebrate: () => true,
        showAchievements: () => true,
      );
      addTearDown(gatedController.dispose);
      final gatedEvents = <CelebrationEvent>[];
      gatedController.events.listen(gatedEvents.add);
      await gatedController.backfill();

      final a = await add('A');
      gated.arm();
      Future<void>? backfill;
      final tap = gatedController.onCompleted(
        a,
        write: () async {
          await tasks.setDone(a.id, done: true);
          backfill = gatedController.backfill();
        },
      );
      // Give a backfill that is not made to wait every chance to run first.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      gated.release();
      await tap;
      expect(backfill, isNotNull);
      await backfill;
      await pumpEventQueue();

      expect(gatedEvents, hasLength(1));
      expect(unlockedIds(gatedEvents.single), ['first_done']);
    },
  );
}
