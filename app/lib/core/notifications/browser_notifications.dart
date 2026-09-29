import 'package:flutter/foundation.dart';

export 'browser_notifications_stub.dart'
    if (dart.library.js_interop) 'browser_notifications_web.dart';

/// What the browser says about notifications for this site.
enum BrowserPermission {
  granted,
  denied,

  /// Not decided yet: asking would show the browser's prompt.
  ask,
}

/// The browser's Notifications API, as thin as the web app needs it.
///
/// `browser_notifications_web.dart` is the only implementation; tests use a
/// fake. Everything about when to show what lives in `TimedNotifications`.
abstract interface class BrowserNotifications {
  /// Current permission; follows changes made in the browser's settings
  /// when the tab is shown again.
  ValueListenable<BrowserPermission> get permission;

  /// Shows the browser's prompt if it still would. Call only from a user
  /// gesture: browsers ignore or penalise a prompt nobody asked for.
  Future<BrowserPermission> requestPermission();

  /// Shows a notification. One with the same [tag] is replaced, so two
  /// tabs showing the same reminder show it once.
  void show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  });

  /// Closes the notification with [tag], if this page showed one.
  void close(String tag);
}

/// Where the page remembers which notifications it already showed, so a
/// reload or a second tab does not show them again. One string.
abstract interface class FiredLog {
  String? read();
  void write(String value);
}

/// A [FiredLog] that lasts as long as the page: tests, and a browser that
/// refuses storage.
class MemoryFiredLog implements FiredLog {
  String? _value;

  @override
  String? read() => _value;

  @override
  void write(String value) => _value = value;
}
