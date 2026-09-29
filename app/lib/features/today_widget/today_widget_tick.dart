import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/row_lookups.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/notifications/notification_texts.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/today_widget/home_widget_bridge.dart';
import 'package:nemo/features/today_widget/today_widget_links.dart';
import 'package:nemo/features/today_widget/today_widget_updater.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:uuid/uuid.dart';

/// Where a running app listens for tasks the widget ticked off. The
/// widget's write goes through its own database connection, which the
/// app's streams do not see; the app is told the task id here.
const widgetTicksPortName = 'nemo.todayWidget.ticks';

/// Ticks [taskId] off from the widget: the same write the app makes --
/// HLC stamp from this device's node and last stamp, outbox, a repeating
/// task's next occurrence, its reminders -- then hands the widget the new
/// list and rebuilds the daily list.
///
/// Returns whether anything was ticked off. A task that is gone or already
/// done is left alone; the widget still gets the current list, so the row
/// it hid while waiting comes back only if it should.
Future<bool> tickFromWidget(
  String taskId, {
  required AppDatabase db,
  required ReminderScheduler reminders,
  required TodayWidgetUpdater widget,
  DailyDigestScheduler Function(TasksRepository tasks, AppBootstrap boot)?
  dailyList,
  DateTime Function() now = DateTime.now,
  String Function()? newId,
}) async {
  final boot = await AppBootstrap.load(db);
  final tasks = TasksRepository(
    db,
    HlcClock(node: boot.nodeId, last: boot.hlcLast),
    newId ?? const Uuid().v4,
    reminders: reminders,
    now: now,
  );
  final task = await db.taskById(taskId);
  final tick = task != null && !task.done && !task.isDeleted;
  if (tick) await tasks.setDone(taskId, done: true);
  await widget.pushTasks(await tasks.watchOpenDated().first, now());
  if (tick) await dailyList?.call(tasks, boot).refresh();
  return tick;
}

/// The widget's background taps, run by `home_widget` in a Flutter engine
/// of their own while the app may or may not be running.
@pragma('vm:entry-point')
Future<void> todayWidgetBackground(Uri? uri) async {
  final taskId = widgetTickedTask(uri);
  if (taskId == null) return;
  final db = AppDatabase.open();
  try {
    final l = await L.delegate.load(PlatformDispatcher.instance.locale);
    final api = LocalNotificationsApi();
    await api.initialize();
    final ticked = await tickFromWidget(
      taskId,
      db: db,
      reminders: remindersFor(api, l),
      widget: TodayWidgetUpdater(const HomeWidgetBridge()),
      dailyList: (tasks, boot) => AndroidDailyDigestScheduler(
        api,
        loadTasks: () => tasks.watchOpenDated().first,
        settings: () => DailyListSettings(
          enabled: boot.dailyList,
          minutes: boot.dailyListMinutes,
        ),
        strings: digestStringsFor(l),
      ),
    );
    if (ticked) {
      IsolateNameServer.lookupPortByName(widgetTicksPortName)?.send(taskId);
    }
  } on Object catch (error) {
    debugPrint('today widget tick: $error');
  } finally {
    await db.close();
  }
}
