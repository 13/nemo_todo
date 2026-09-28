import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';

final dailyDigestSchedulerProvider = Provider<DailyDigestScheduler>((ref) {
  final api = ref.watch(notificationsApiProvider);
  final strings = ref.watch(digestStringsProvider);
  if (api == null || strings == null) return const NoopDailyDigestScheduler();
  return AndroidDailyDigestScheduler(
    api,
    loadTasks: () => ref.read(tasksRepositoryProvider).watchOpenDated().first,
    settings: () => DailyListSettings(
      enabled: ref.read(dailyListEnabledProvider),
      minutes: ref.read(dailyListMinutesProvider),
    ),
    strings: strings,
    now: ref.watch(nowProvider),
  );
});

/// How long the refresher waits for a burst of writes (a sync, an import)
/// to finish before rebuilding the week once.
final dailyListDebounceProvider = Provider<Duration>(
  (_) => const Duration(seconds: 1),
);

/// Keeps the scheduled daily lists in step with tasks, settings and the
/// date. Read once by `NemoApp`; lives as long as the app.
final dailyListRefresherProvider = Provider<void>((ref) {
  final scheduler = ref.watch(dailyDigestSchedulerProvider);
  final wait = ref.watch(dailyListDebounceProvider);
  Timer? pending;
  void schedule() {
    pending?.cancel();
    pending = Timer(wait, () => unawaited(scheduler.refresh()));
  }

  // Emits at once (the start), then on every change to an open dated task.
  final tasks = ref
      .watch(tasksRepositoryProvider)
      .watchOpenDated()
      .listen((_) => schedule());
  ref
    ..listen(dailyListEnabledProvider, (_, _) => schedule())
    ..listen(dailyListMinutesProvider, (_, _) => schedule());
  // The day may have rolled over while the app slept.
  final lifecycle = AppLifecycleListener(onResume: schedule);
  ref.onDispose(() {
    pending?.cancel();
    unawaited(tasks.cancel());
    lifecycle.dispose();
  });
});
