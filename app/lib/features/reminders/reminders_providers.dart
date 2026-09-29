import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/notifications/reminder_resync.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/daily_list/daily_list_providers.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';

/// Keeps the page's reminders in step with every task that could have one.
/// Read once by `NemoApp`; does nothing where reminders outlive the app.
final reminderResyncProvider = Provider<void>((ref) {
  if (!ref.watch(remindersInPageProvider)) return;
  final resync = ReminderResync(ref.watch(reminderSchedulerProvider));
  final wait = ref.watch(dailyListDebounceProvider);
  Timer? pending;
  var running = Future<void>.value();
  // Emits at once (the page's start), then on every change -- this tab's,
  // a sync's, or another tab's.
  final tasks = ref.watch(tasksRepositoryProvider).watchOpenDated().listen((
    open,
  ) {
    pending?.cancel();
    pending = Timer(wait, () {
      // One pass at a time, in order, so the last list always wins.
      running = running.then((_) => resync.apply(open)).catchError((
        Object error,
      ) {
        debugPrint('Reminders not rescheduled: $error');
      });
    });
  });
  ref.onDispose(() {
    pending?.cancel();
    unawaited(tasks.cancel());
  });
});
