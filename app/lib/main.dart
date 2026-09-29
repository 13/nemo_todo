import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/app.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/notifications/browser_notifications.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/notifications/notification_texts.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/notifications/timed_notifications.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/splash/splash.dart';
import 'package:nemo/core/theme/material_theme.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo/features/today_widget/today_widget_providers.dart';
import 'package:nemo/features/today_widget/today_widget_setup.dart';
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
    // Set before this was remembered, or in another tab: the page's next
    // loading screen should match whatever the app now uses.
    rememberTheme(boot.bootstrap.themeMode.name);
    rememberStyle(boot.bootstrap.appStyle.name);
    final photoStore = await openPhotoStore();
    final widget = await openTodayWidget(tapped);
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
          browserNotificationsProvider.overrideWithValue(
            boot.notifications.browser,
          ),
          notificationRouteProvider.overrideWithValue(tapped),
          photoStoreProvider.overrideWithValue(photoStore),
          wallpaperSchemesProvider.overrideWithValue(boot.wallpaper),
          if (widget != null) ...[
            todayWidgetBridgeProvider.overrideWithValue(widget.bridge),
            todayWidgetTicksProvider.overrideWithValue(widget.ticks),
          ],
        ],
        child: const NemoApp(),
      ),
    );
  } on Object catch (error) {
    // The error screen reads no providers; there is deliberately no scope
    // here, because the providers it would hold are what failed to start.
    _run(StartupErrorApp(error: error));
  }
}

/// Starts [app] and, once its first frame is on screen, takes down the web
/// page's loading screen -- not before, or the page would go blank again
/// between the two.
void _run(Widget app) {
  // The app brings its own ProviderScope; the startup error screen has
  // none on purpose (see [main]), which the lint cannot see from here.
  // ignore: riverpod_lint/missing_provider_scope
  runApp(app);
  WidgetsBinding.instance.addPostFrameCallback((_) => removeSplash());
}

typedef _Notifications = ({
  NotificationsApi? api,
  ReminderScheduler reminders,
  DigestStrings? digestStrings,
  BrowserNotifications? browser,
});

/// Everything that has to exist before the first frame.
Future<
  ({
    AppBootstrap bootstrap,
    _Notifications notifications,
    WallpaperSchemes? wallpaper,
  })
>
_prepare(AppDatabase db, ValueNotifier<String?> tapped) async {
  final boot = await AppBootstrap.load(db);
  // The Inbox exists before the first frame, so every screen can rely on it.
  await ListsRepository(
    db,
    HlcClock(node: boot.nodeId, last: boot.hlcLast),
    const Uuid().v4,
  ).ensureInbox();
  return (
    bootstrap: boot,
    notifications: await _openNotifications(tapped),
    wallpaper: await loadWallpaperSchemes(),
  );
}

/// Local notifications on Android, the browser's on the web while a tab
/// is open; nothing to schedule elsewhere.
///
/// A tap while the app runs lands in [tapped]; so does the tap that
/// started it, read once here.
Future<_Notifications> _openNotifications(ValueNotifier<String?> tapped) async {
  const none = (
    api: null,
    reminders: NoopReminderScheduler(),
    digestStrings: null,
    browser: null,
  );
  final NotificationsApi api;
  BrowserNotifications? browser;
  var missedWindow = Duration.zero;
  if (kIsWeb) {
    browser = openBrowserNotifications();
    if (browser == null) return none;
    api = TimedNotifications(browser, fired: openFiredLog());
    missedWindow = TimedNotifications.missedWindow;
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    api = LocalNotificationsApi();
  } else {
    return none;
  }
  // Strings for the notification channels come from the device locale,
  // which is fixed for the life of a channel; the app locale may differ.
  final l = await L.delegate.load(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  await api.initialize(onTap: (payload) => tapped.value = payload);
  // Only overwrite `tapped` when the launch actually came from a
  // notification -- a live tap can arrive between `initialize` and here,
  // and a null launch payload must not clobber it.
  final launched = await api.launchPayload();
  if (launched != null) tapped.value = launched;
  return (
    api: api,
    reminders: remindersFor(api, l, missedWindow: missedWindow),
    digestStrings: digestStringsFor(l),
    browser: browser,
  );
}
