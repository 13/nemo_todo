import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/app.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/notifications/android_reminder_scheduler.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  final boot = await AppBootstrap.load(db);
  final clock = HlcClock(node: boot.nodeId, last: boot.hlcLast);
  // The Inbox exists before the first frame, so every screen can rely on it.
  await ListsRepository(db, clock, const Uuid().v4).ensureInbox();
  final reminders = await _openReminders();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
        reminderSchedulerProvider.overrideWithValue(reminders),
      ],
      child: const NemoApp(),
    ),
  );
}

/// Local notifications on Android; nothing to schedule elsewhere.
Future<ReminderScheduler> _openReminders() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoopReminderScheduler();
  }
  // Strings for the notification channel come from the device locale, which
  // is fixed for the life of the channel; the app locale may differ later.
  final l = await L.delegate.load(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final scheduler = AndroidReminderScheduler(
    LocalNotificationsApi(),
    channelName: l.remindersChannelName,
    channelDescription: l.remindersChannelDescription,
    body: l.remindersDueNow,
  );
  await scheduler.init();
  return scheduler;
}
