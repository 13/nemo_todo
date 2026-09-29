import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';

/// Reminders as notifications at a task's due time: local notifications
/// on Android, and on the web the page's `TimedNotifications`.
class AndroidReminderScheduler implements ReminderScheduler {
  AndroidReminderScheduler(
    this._api, {
    required this.channelName,
    required this.channelDescription,
    required this.body,
    this.missedWindow = Duration.zero,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsApi _api;
  final String channelName;
  final String channelDescription;

  /// Notification text under the task title, e.g. "Due now".
  final String body;

  /// How long after its due time a task still wants its reminder. Zero on
  /// Android, whose alarms outlive the app; on the web a page loaded just
  /// after the due time still shows what no page was open for.
  final Duration missedWindow;
  final DateTime Function() _now;

  /// Where a tap goes: `Routes.task`, spelled out so this file does not
  /// pull in the router and every screen with it.
  static String payloadFor(String taskId) => '/tasks/$taskId';

  /// Stable non-negative notification id for a task id.
  static int notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  @override
  Future<bool> ensurePermission() => _api.requestPermission();

  @override
  Future<void> sync(Task task) async {
    if (!wantsReminder(task, _now().subtract(missedWindow))) {
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
      payload: payloadFor(task.id),
    );
  }

  @override
  Future<void> cancel(String taskId) => _api.cancel(notificationId(taskId));
}
