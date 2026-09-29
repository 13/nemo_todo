import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/app.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/notifications/android_reminder_scheduler.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/splash/splash.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
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
  // Where a tapped notification asks to go; NemoApp follows it.
  final tapped = ValueNotifier<String?>(null);
  try {
    final boot = await _prepare(db, tapped).timeout(startupTimeout);
    final photoStore = await openPhotoStore();
    _run(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bootstrapProvider.overrideWithValue(boot.bootstrap),
          reminderSchedulerProvider.overrideWithValue(
            boot.notifications.reminders,
          ),
          notificationsApiProvider.overrideWithValue(boot.notifications.api),
          digestStringsProvider.overrideWithValue(
            boot.notifications.digestStrings,
          ),
          notificationRouteProvider.overrideWithValue(tapped),
          photoStoreProvider.overrideWithValue(photoStore),
        ],
        child: const NemoApp(),
      ),
    );
  } on Object catch (error) {
    // The error screen reads no providers; there is deliberately no scope
    // here, because the providers it would hold are what failed to start.
    // ignore: riverpod_lint/missing_provider_scope
    _run(StartupErrorApp(error: error));
  }
}

/// Starts [app] and, once its first frame is on screen, takes down the web
/// page's loading screen -- not before, or the page would go blank again
/// between the two.
void _run(Widget app) {
  runApp(app);
  WidgetsBinding.instance.addPostFrameCallback((_) => removeSplash());
}

typedef _Notifications = ({
  NotificationsApi? api,
  ReminderScheduler reminders,
  DigestStrings? digestStrings,
});

/// Everything that has to exist before the first frame.
Future<({AppBootstrap bootstrap, _Notifications notifications})> _prepare(
  AppDatabase db,
  ValueNotifier<String?> tapped,
) async {
  final boot = await AppBootstrap.load(db);
  // The Inbox exists before the first frame, so every screen can rely on it.
  await ListsRepository(
    db,
    HlcClock(node: boot.nodeId, last: boot.hlcLast),
    const Uuid().v4,
  ).ensureInbox();
  return (bootstrap: boot, notifications: await _openNotifications(tapped));
}

/// Local notifications on Android; nothing to schedule elsewhere.
///
/// A tap while the app runs lands in [tapped]; so does the tap that
/// started it, read once here.
Future<_Notifications> _openNotifications(ValueNotifier<String?> tapped) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return (
      api: null,
      reminders: const NoopReminderScheduler(),
      digestStrings: null,
    );
  }
  // Strings for the notification channels come from the device locale,
  // which is fixed for the life of a channel; the app locale may differ.
  final l = await L.delegate.load(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final api = LocalNotificationsApi();
  await api.initialize(onTap: (payload) => tapped.value = payload);
  // Only overwrite `tapped` when the launch actually came from a
  // notification -- a live tap can arrive between `initialize` and here,
  // and a null launch payload must not clobber it.
  final launched = await api.launchPayload();
  if (launched != null) tapped.value = launched;
  return (
    api: api,
    reminders: AndroidReminderScheduler(
      api,
      channelName: l.remindersChannelName,
      channelDescription: l.remindersChannelDescription,
      body: l.remindersDueNow,
    ),
    digestStrings: DigestStrings(
      channelName: l.dailyListChannelName,
      channelDescription: l.dailyListChannelDescription,
      title: (today, overdue) => overdue == 0
          ? l.dailyListToday(today)
          : today == 0
          ? l.dailyListOverdue(overdue)
          : l.dailyListTodayOverdue(today, overdue),
      more: l.dailyListMore,
    ),
  );
}
