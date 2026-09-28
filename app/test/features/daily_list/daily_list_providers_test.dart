import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/daily_list/daily_list_providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';

import '../../support/test_db.dart';

class CountingScheduler implements DailyDigestScheduler {
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late CountingScheduler scheduler;
  late String inbox;

  // Ruling R2: the debounce is overridden to 50ms and settle() waits
  // 150ms (not 10/30) -- five sequential DB writes can take longer than
  // 10ms and would split into two refreshes, making "a write reschedules
  // once" flaky.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  setUp(() async {
    final db = testDatabase();
    addTearDown(db.close);
    inbox = (await ListsRepository(
      db,
      testClock(),
      sequentialIds('l'),
    ).ensureInbox()).id;
    final boot = await AppBootstrap.load(db);
    scheduler = CountingScheduler();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
        nowProvider.overrideWithValue(() => testNow),
        idGeneratorProvider.overrideWithValue(sequentialIds()),
        dailyDigestSchedulerProvider.overrideWithValue(scheduler),
        dailyListDebounceProvider.overrideWithValue(
          const Duration(milliseconds: 50),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(dailyListRefresherProvider);
    await settle();
  });

  test('refreshes once at start', () {
    expect(scheduler.refreshes, 1);
  });

  test('a write reschedules once', () async {
    final tasks = container.read(tasksRepositoryProvider);
    for (var i = 0; i < 5; i++) {
      await tasks.create(
        listId: inbox,
        title: 'T$i',
        dueAt: testNow.millisecondsSinceEpoch,
      );
    }
    await settle();
    expect(scheduler.refreshes, 2);
  });

  test('changing a setting reschedules', () async {
    await container.read(dailyListMinutesProvider.notifier).set(420);
    await settle();
    expect(scheduler.refreshes, 2);
    await container.read(dailyListEnabledProvider.notifier).set(enabled: true);
    await settle();
    expect(scheduler.refreshes, 3);
  });

  test('without a notifications api the scheduler is a no-op', () {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);
    expect(
      plain.read(dailyDigestSchedulerProvider),
      isA<NoopDailyDigestScheduler>(),
    );
  });
}
