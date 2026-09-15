import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/achievements/ui/achievements_screen.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/celebrations/data/celebration_sound.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/celebrations/ui/celebration_overlay.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/settings/data/server_build.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_celebrations.dart';
import '../../support/fake_sync.dart';
import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// Tasks due today in the inbox, and switches set before the app starts.
Future<void> Function(AppDatabase, TaskList) seedToday(
  List<String> titles, {
  Map<String, String> kv = const {},
  bool done = false,
}) => (db, inbox) async {
  for (final e in kv.entries) {
    await KvStore(db).set(e.key, e.value);
  }
  final tasks = TasksRepository(
    db,
    testClock('seed'),
    sequentialIds('task'),
    reminders: const NoopReminderScheduler(),
    now: () => testNow,
  );
  for (final title in titles) {
    final t = await tasks.create(
      listId: inbox.id,
      title: title,
      dueAt: dayStartMs(testNow),
    );
    if (done) await tasks.setDone(t.id, done: true);
  }
};

Future<void> tickOff(WidgetTester tester, String title) async {
  await tester.tap(
    find.descendant(
      of: find.widgetWithText(InkWell, title),
      matching: find.byType(DoneCheck),
    ),
  );
  // Confetti keeps frames coming, so pump a fixed while, not until settled.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

List<String> recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return haptics;
}

/// Celebrates whatever a test sends, and records nothing.
class _ScriptedCelebrations extends CelebrationController {
  _ScriptedCelebrations(AppDatabase db, this.events)
    : super(
        AchievementsRepository(db),
        now: () => testNow,
        celebrate: () => true,
        showAchievements: () => true,
      );

  @override
  final Stream<CelebrationEvent> events;

  @override
  Future<void> backfill() async {}
}

/// Bumped to make the celebration controller provider build a new one.
class _Generation extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _generationProvider = NotifierProvider<_Generation, int>(_Generation.new);

ConfettiControllerState confetti(WidgetTester tester) => tester
    .widget<ConfettiWidget>(find.byType(ConfettiWidget))
    .confettiController
    .state;

void main() {
  appTest('an unlock shows a banner, confetti and plays the sound', (
    tester,
  ) async {
    final sound = RecordingCelebrationSound();
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      celebrate: true,
      sound: sound,
      seed: seedToday(
        ['First', 'Second'],
        kv: {KvKeys.celebrationSound: 'true'},
      ),
    );

    await tickOff(tester, 'First');

    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
    expect(confetti(tester), ConfettiControllerState.playing);
    expect(sound.plays, 1);
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));

    await tester.tap(find.byKey(const Key('achievement-banner')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(AchievementsScreen), findsOneWidget);
  });

  appTest('confetti is painted even when frames come slower than 60 fps', (
    tester,
  ) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['Only'], kv: {KvKeys.achievements: 'false'}),
    );

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InkWell, 'Only'),
        matching: find.byType(DoneCheck),
      ),
    );
    // The package steps particles on the wall clock; let real time pass
    // between frames, as a busy phone or a throttled browser tab would.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final painter =
        tester
                .renderObject<RenderCustomPaint>(
                  find.descendant(
                    of: find.byType(ConfettiWidget),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .foregroundPainter!
            as ParticlePainter;
    expect(painter.particles.where((p) => p.active), isNotEmpty);
  });

  appTest('a plain tick is a light haptic and nothing else', (tester) async {
    final sound = RecordingCelebrationSound();
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      celebrate: true,
      sound: sound,
      seed: seedToday(['First', 'Second', 'Third']),
    );
    await tickOff(tester, 'First');
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    haptics.clear();

    await tickOff(tester, 'Second');

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
    expect(confetti(tester), isNot(ConfettiControllerState.playing));
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(sound.plays, 0, reason: 'sound is off by default');
  });

  appTest('reduced motion keeps the banner and drops the confetti', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second']),
    );

    await tickOff(tester, 'First');

    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(confetti(tester), isNot(ConfettiControllerState.playing));
  });

  appTest('with celebrations off an unlock is only a banner', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second'], kv: {KvKeys.celebrations: 'false'}),
    );

    await tickOff(tester, 'First');

    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(confetti(tester), isNot(ConfettiControllerState.playing));
    expect(haptics, isEmpty);
  });

  appTest('clearing the day with achievements off is confetti, no banner', (
    tester,
  ) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['Only'], kv: {KvKeys.achievements: 'false'}),
    );

    await tickOff(tester, 'Only');

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
    expect(confetti(tester), ConfettiControllerState.playing);
  });

  appTest('a rebuilt builder hands the overlay its new child', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await ListsRepository(
      db,
      testClock('seed'),
      sequentialIds('l'),
    ).ensureInbox();
    final boot = await AppBootstrap.load(db);
    final unlocks = StreamController<CelebrationEvent>.broadcast();
    addTearDown(unlocks.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
        nowProvider.overrideWithValue(() => testNow),
        idGeneratorProvider.overrideWithValue(sequentialIds()),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        celebrationSoundProvider.overrideWithValue(RecordingCelebrationSound()),
        serverBuildFetcherProvider.overrideWithValue((_) async => null),
        celebrationControllerProvider.overrideWith(
          (ref) => _ScriptedCelebrations(db, unlocks.stream),
        ),
      ],
    );
    final label = ValueNotifier('first');
    addTearDown(label.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ValueListenableBuilder<String>(
          valueListenable: label,
          builder: (context, text, _) => MaterialApp(
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: const SizedBox.shrink(),
            builder: (context, child) => CelebrationOverlay(
              onOpenAchievements: () {},
              child: Text(text),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    label.value = 'second';
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);

    // The banner's close button shows a tooltip, which needs an Overlay the
    // overlay brings along itself.
    unlocks.add(AchievementsUnlocked([achievementCatalog.first]));
    // The stream delivers in a microtask, after the frame that pump drew.
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  appTest('the overlay follows a new celebration controller', (tester) async {
    var built = 0;
    final app = await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second']),
      overrides: [
        celebrationControllerProvider.overrideWith((ref) {
          ref.watch(_generationProvider);
          built++;
          final controller = CelebrationController(
            ref.watch(achievementsRepositoryProvider),
            now: ref.watch(nowProvider),
            celebrate: () => ref.read(celebrationsEnabledProvider),
            showAchievements: () => ref.read(achievementsEnabledProvider),
          );
          ref.onDispose(controller.dispose);
          return controller;
        }),
      ],
    );
    expect(built, 1);

    app.container.read(_generationProvider.notifier).bump();
    await tester.pump();

    await tickOff(tester, 'First');

    expect(built, 2, reason: 'the tick went through a new controller');
    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
  });

  appTest("a sync's unlocks are recorded before the next tick", (tester) async {
    final client = FakeSyncClient([]);
    final app = await pumpApp(
      tester,
      celebrate: true,
      settle: false,
      overrides: [
        authStorageProvider.overrideWithValue(MemoryAuthStorage('secret')),
        syncClientFactoryProvider.overrideWithValue((_, _) => client),
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
      ],
      seed: (db, inbox) async {
        final kv = KvStore(db);
        await kv.set(KvKeys.serverUrl, 'https://nemo.test');
        await kv.set(KvKeys.username, 'ben');
        await seedToday(['First', 'Second'])(db, inbox);
      },
    );
    // Nothing is recorded as reached before the sync.
    expect(await AchievementsRepository(app.db).seen(), isEmpty);

    // Another device completed ten tasks.
    client.responses.add(
      SyncResponse(
        cursor: 1,
        serverHlc: Hlc(
          millis: testNowMs + 1000,
          counter: 0,
          node: 'srv',
        ).toString(),
        changes: [
          for (var i = 0; i < 10; i++)
            SyncChange.task(
              Task(
                id: 'remote-$i',
                listId: app.inbox.id,
                title: 'Remote $i',
                sortKey: 'V$i',
                updatedAt: Hlc(
                  millis: testNowMs + 500,
                  counter: i,
                  node: 'other',
                ).toString(),
                done: true,
                doneAt: testNowMs - const Duration(hours: 1).inMilliseconds,
              ),
            ),
        ],
      ),
    );
    unawaited(app.container.read(syncEngineProvider.notifier).syncNow());
    await settleSync(tester);
    expect(
      (await app.db.select(app.db.tasks).get()).where((t) => t.done),
      hasLength(10),
    );

    // 'Second' stays open, so Today is not cleared by this tick.
    await tickOff(tester, 'First');

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
    expect(
      await AchievementsRepository(app.db).seen(),
      containsAll(['first_done', 'done_10']),
    );
  });

  appTest('history from before is recorded without a celebration', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['Old'], done: true),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
    expect(
      await AchievementsRepository(app.db).seen(),
      containsAll(['first_done']),
    );
  });

  appTest('the banner hides itself after four seconds', (tester) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second']),
    );
    await tickOff(tester, 'First');
    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
  });

  appTest('with accessible navigation the banner waits to be closed', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second']),
    );
    await tickOff(tester, 'First');

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.byKey(const Key('achievement-banner')), findsNothing);
  });
}
