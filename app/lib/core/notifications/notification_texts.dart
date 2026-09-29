import 'package:nemo/core/notifications/android_reminder_scheduler.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Task reminders through [api], worded in [l].
///
/// [l] should be the device locale's, not the app's: a notification
/// channel's name is fixed for its life. Used by the app and by the Today
/// widget's background tick, which schedules a repeating task's next
/// reminder.
AndroidReminderScheduler remindersFor(
  NotificationsApi api,
  L l, {
  Duration missedWindow = Duration.zero,
}) => AndroidReminderScheduler(
  api,
  channelName: l.remindersChannelName,
  channelDescription: l.remindersChannelDescription,
  body: l.remindersDueNow,
  missedWindow: missedWindow,
);

/// The daily list's wording in [l].
DigestStrings digestStringsFor(L l) => DigestStrings(
  channelName: l.dailyListChannelName,
  channelDescription: l.dailyListChannelDescription,
  title: (today, overdue) => overdue == 0
      ? l.dailyListToday(today)
      : today == 0
      ? l.dailyListOverdue(overdue)
      : l.dailyListTodayOverdue(today, overdue),
  more: l.dailyListMore,
);
