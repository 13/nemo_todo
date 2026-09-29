import 'package:nemo/core/notifications/browser_notifications.dart';

/// Off the web there is no browser to show notifications.
BrowserNotifications? openBrowserNotifications() => null;

/// Off the web nothing is shared between tabs.
FiredLog openFiredLog() => MemoryFiredLog();
