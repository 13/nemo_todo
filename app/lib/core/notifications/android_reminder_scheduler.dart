import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';

/// Reminders as local notifications at a task's due time.
class AndroidReminderScheduler implements ReminderScheduler {
  AndroidReminderScheduler(
    this._api, {
    required this.channelName,
    required this.channelDescription,
    required this.body,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsApi _api;
  final String channelName;
  final String channelDescription;

  /// Notification text under the task title, e.g. "Due now".
  final String body;
  final DateTime Function() _now;

  /// Stable non-negative notification id for a task id.
  static int notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  @override
  Future<void> init() => _api.initialize();

  @override
  Future<bool> ensurePermission() => _api.requestPermission();

  @override
  Future<void> sync(Task task) async {
    if (!wantsReminder(task, _now())) {
      await cancel(task.id);
      return;
    }
    await _api.scheduleAt(
      id: notificationId(task.id),
      title: task.title,
      body: body,
      epochMs: task.dueAt!,
      channelName: channelName,
      channelDescription: channelDescription,
    );
  }

  @override
  Future<void> cancel(String taskId) => _api.cancel(notificationId(taskId));
}
