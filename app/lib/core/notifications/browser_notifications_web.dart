import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:nemo/core/notifications/browser_notifications.dart';
import 'package:web/web.dart' as web;

/// The page's Notifications API, or null where the browser has none.
BrowserNotifications? openBrowserNotifications() {
  if (!web.window.has('Notification')) return null;
  return _WebNotifications();
}

/// The fired log in `localStorage`, which every tab of this origin shares.
FiredLog openFiredLog() => _LocalStorageFiredLog();

BrowserPermission _read() => switch (web.Notification.permission) {
  'granted' => BrowserPermission.granted,
  'denied' => BrowserPermission.denied,
  _ => BrowserPermission.ask,
};

class _WebNotifications implements BrowserNotifications {
  _WebNotifications() {
    // Coming back from the browser's site settings, where notifications
    // may have been allowed or blocked, is coming back to the tab.
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'visible') {
          _permission.value = _read();
        }
      }).toJS,
    );
  }

  final _permission = ValueNotifier<BrowserPermission>(_read());
  final _shown = <String, web.Notification>{};

  @override
  ValueListenable<BrowserPermission> get permission => _permission;

  @override
  Future<BrowserPermission> requestPermission() async {
    try {
      await web.Notification.requestPermission().toDart;
    } on Object catch (error) {
      debugPrint('Notification permission not asked: $error');
    }
    return _permission.value = _read();
  }

  @override
  void show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  }) {
    try {
      final notification = web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          tag: tag,
          icon: Uri.base.resolve('icons/Icon-192.png').toString(),
        ),
      );
      notification.onclick = ((web.Event event) {
        // Handled here rather than by the browser's default, which not
        // every browser has: bring the tab forward, then open the task.
        event.preventDefault();
        web.window.focus();
        notification.close();
        _shown.remove(tag);
        onClick();
      }).toJS;
      _shown[tag] = notification;
      // Chrome on Android refuses the constructor outright: only a service
      // worker may post there. Nothing is shown then, and nothing breaks.
    } on Object catch (error) {
      debugPrint('Notification not shown: $error');
    }
  }

  @override
  void close(String tag) => _shown.remove(tag)?.close();
}

class _LocalStorageFiredLog implements FiredLog {
  static const _key = 'nemo-notified';

  // Storage can be switched off, or full; the log is a convenience, so the
  // page carries on without it.
  final _fallback = MemoryFiredLog();

  @override
  String? read() {
    try {
      return web.window.localStorage.getItem(_key);
    } on Object {
      return _fallback.read();
    }
  }

  @override
  void write(String value) {
    try {
      web.window.localStorage.setItem(_key, value);
    } on Object {
      _fallback.write(value);
    }
  }
}
