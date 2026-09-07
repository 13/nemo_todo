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
import 'package:nemo/screens/startup_error_screen.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:uuid/uuid.dart';

/// How long the database gets to open before the app gives up on it.
///
/// The web build stores data through a browser worker, and a browser that
/// refuses to start one leaves the open call waiting rather than failing.
/// Without this the app would show nothing at all, for ever.
const startupTimeout = Duration(seconds: 15);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  try {
    final boot = await _prepare(db).timeout(startupTimeout);
    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bootstrapProvider.overrideWithValue(boot.bootstrap),
          reminderSchedulerProvider.overrideWithValue(boot.reminders),
        ],
        child: const NemoApp(),
      ),
    );
  } on Object catch (error) {
    runApp(StartupErrorApp(error: error));
  }
}

/// Everything that has to exist before the first frame.
Future<({AppBootstrap bootstrap, ReminderScheduler reminders})> _prepare(
  AppDatabase db,
) async {
  final boot = await AppBootstrap.load(db);
  // The Inbox exists before the first frame, so every screen can rely on it.
  await ListsRepository(
    db,
    HlcClock(node: boot.nodeId, last: boot.hlcLast),
    const Uuid().v4,
  ).ensureInbox();
  return (bootstrap: boot, reminders: await _openReminders());
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
