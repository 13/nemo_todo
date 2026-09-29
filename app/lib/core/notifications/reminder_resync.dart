import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';

/// Brings the reminders into line with the tasks that could have one.
///
/// For the web, where the schedule lives in the page: it has to be built
/// again every time the page loads, and a task ticked off in another tab of
/// the same browser reaches this one only through the database's streams,
/// never through this tab's `ReminderScheduler.sync`.
class ReminderResync {
  ReminderResync(this._reminders);

  final ReminderScheduler _reminders;
  var _last = <String>{};

  /// [tasks] is every task that could remind: open, dated and not deleted.
  /// Each is synced; one that was here last time and is not now (done,
  /// deleted, undated) has its reminder cancelled.
  Future<void> apply(List<Task> tasks) async {
    final current = {for (final t in tasks) t.id};
    for (final task in tasks) {
      await _reminders.sync(task);
    }
    for (final gone in _last.difference(current)) {
      await _reminders.cancel(gone);
    }
    _last = current;
  }
}
