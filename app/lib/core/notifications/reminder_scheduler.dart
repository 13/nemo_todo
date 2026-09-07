import 'package:nemo_core/nemo_core.dart';

/// Schedules a local notification at a task's due time.
abstract interface class ReminderScheduler {
  Future<void> init();

  /// Asks for notification permission where needed; true when granted.
  Future<bool> ensurePermission();

  /// Schedules, reschedules or cancels the reminder for [task] so that it
  /// matches the task's current state.
  Future<void> sync(Task task);

  Future<void> cancel(String taskId);
}

/// Web and tests: reminders are not available.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> init() async {}

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> sync(Task task) async {}

  @override
  Future<void> cancel(String taskId) async {}
}

/// Whether [task] should currently have a reminder scheduled.
bool wantsReminder(Task task, DateTime now) {
  final dueAt = task.dueAt;
  return task.remind &&
      !task.done &&
      !task.isDeleted &&
      dueAt != null &&
      dueAt > now.millisecondsSinceEpoch;
}
