import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/ui/achievements_screen.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_celebrations.dart';
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
}
