import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/features/today_widget/today_widget_bridge.dart';
import 'package:nemo/features/today_widget/today_widget_data.dart';
import 'package:nemo/features/today_widget/today_widget_updater.dart';
import 'package:nemo_core/nemo_core.dart';

/// The home-screen widget, where there is one (Android); `main` sets it.
final todayWidgetBridgeProvider = Provider<TodayWidgetBridge?>((_) => null);

/// Ids of tasks the widget ticked off in the background while the app
/// ran; `main` feeds it from the port the background tick reports to.
final todayWidgetTicksProvider = Provider<Stream<String>>(
  (_) => const Stream.empty(),
);

/// How long the widget waits for a burst of writes (a sync, an import)
/// to finish before it is handed the list once.
final todayWidgetDebounceProvider = Provider<Duration>(
  (_) => const Duration(seconds: 1),
);

/// Keeps the Today widget in step with the tasks and the app's look. Read
/// once by `NemoApp`; lives as long as the app.
///
/// The widget picks today's tasks from a week's worth by itself, and
/// redraws at midnight and after a reboot without the app, so the app only
/// has to push when something changes -- and on resume, which moves the
/// week along.
final todayWidgetSyncProvider = Provider<void>((ref) {
  final bridge = ref.watch(todayWidgetBridgeProvider);
  if (bridge == null) return;
  final updater = TodayWidgetUpdater(bridge);
  final repository = ref.watch(tasksRepositoryProvider);
  final now = ref.watch(nowProvider);
  final wait = ref.watch(todayWidgetDebounceProvider);

  List<Task>? latest;
  Timer? pending;
  void pushTasks() {
    pending?.cancel();
    pending = Timer(wait, () {
      final tasks = latest;
      if (tasks != null) unawaited(updater.pushTasks(tasks, now()));
    });
  }

  // Emits at once (the start), then on every change to an open dated task.
  final tasks = repository.watchOpenDated().listen((next) {
    latest = next;
    pushTasks();
  });

  void pushLook() {
    final style = ref.read(appStyleControllerProvider);
    final accent = ref.read(accentControllerProvider);
    final wallpaper = ref.read(wallpaperSchemesProvider);
    ThemeData theme(Brightness brightness) =>
        AppTheme.build(style, brightness, wallpaper: wallpaper, accent: accent);
    unawaited(
      updater.pushLook(
        widgetLook(
          mode: ref.read(themeModeControllerProvider),
          style: style,
          light: theme(Brightness.light),
          dark: theme(Brightness.dark),
          hasWallpaper: wallpaper != null,
          accent: accent,
        ),
      ),
    );
  }

  pushLook();
  ref
    ..listen(appStyleControllerProvider, (_, _) => pushLook())
    ..listen(accentControllerProvider, (_, _) => pushLook())
    ..listen(themeModeControllerProvider, (_, _) => pushLook());

  // A tick from the widget was written through another connection: tell
  // this one's streams (Today, the outbox count that wakes the sync) and
  // move this device's clock past the stamp it used.
  final db = ref.watch(appDatabaseProvider);
  final clock = ref.watch(hlcClockProvider);
  final ticks = ref.watch(todayWidgetTicksProvider).listen((_) async {
    final last = await KvStore(db).get(KvKeys.hlcLast);
    if (last != null) clock.receive(Hlc.parse(last));
    db.markTablesUpdated([db.tasks, db.subtasks, db.outbox, db.kv]);
  });

  final lifecycle = AppLifecycleListener(onResume: pushTasks);
  ref.onDispose(() {
    pending?.cancel();
    unawaited(tasks.cancel());
    unawaited(ticks.cancel());
    lifecycle.dispose();
  });
});
