import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nemo/core/notifications/browser_notifications.dart';

/// Records what the page asked the browser to show and close.
class FakeBrowser implements BrowserNotifications {
  FakeBrowser({BrowserPermission permission = BrowserPermission.granted})
    : _permission = ValueNotifier(permission);

  final ValueNotifier<BrowserPermission> _permission;
  final shown = <({String tag, String title, String body, DateTime at})>[];
  final closed = <String>[];
  final _clicks = <String, void Function()>{};
  int requests = 0;

  /// What the prompt answers when [requestPermission] is called.
  BrowserPermission answer = BrowserPermission.granted;

  /// Set by tests to stamp [shown] entries with the fake time.
  DateTime Function() now = DateTime.now;

  BrowserPermission get current => _permission.value;
  set current(BrowserPermission value) => _permission.value = value;

  @override
  ValueListenable<BrowserPermission> get permission => _permission;

  @override
  Future<BrowserPermission> requestPermission() async {
    requests++;
    if (_permission.value == BrowserPermission.ask) _permission.value = answer;
    return _permission.value;
  }

  @override
  void show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  }) {
    shown.add((tag: tag, title: title, body: body, at: now()));
    _clicks[tag] = onClick;
  }

  @override
  void close(String tag) => closed.add(tag);

  void click(String tag) => _clicks[tag]!();
}

/// A clock and timers that move only when told to.
class FakeTimeline {
  FakeTimeline(this.now);

  DateTime now;
  final _timers = <_FakeTimer>[];

  /// Waits of the timers still set, soonest first.
  List<Duration> get pending => [
    for (final t in _timers)
      if (t.isActive) t.due.difference(now),
  ]..sort();

  Timer start(Duration wait, void Function() then) {
    final timer = _FakeTimer(now.add(wait), then);
    _timers.add(timer);
    return timer;
  }

  /// Moves time on by [by], firing each timer at its time on the way.
  void advance(Duration by) {
    final end = now.add(by);
    while (true) {
      final due = _timers.where((t) => t.isActive && !t.due.isAfter(end));
      if (due.isEmpty) break;
      final next = due.reduce((a, b) => a.due.isAfter(b.due) ? b : a);
      now = next.due;
      next.fire();
    }
    now = end;
  }

  /// Moves time on by [by] without any timer firing -- a sleeping
  /// computer -- then fires whatever came due, late.
  void sleep(Duration by) {
    now = now.add(by);
    for (final t in [..._timers]) {
      if (t.isActive && !t.due.isAfter(now)) t.fire();
    }
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.due, this._then);

  final DateTime due;
  final void Function() _then;
  var _active = true;

  void fire() {
    _active = false;
    _then();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
