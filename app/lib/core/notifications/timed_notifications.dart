import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nemo/core/notifications/browser_notifications.dart';
import 'package:nemo/core/notifications/notifications_api.dart';

typedef StartTimer = Timer Function(Duration wait, void Function() then);

/// Scheduled notifications for the web, where nothing outside the page
/// keeps a schedule: the page holds it and shows each one through the
/// browser when its time comes, while a tab is open.
///
/// Built from the same calls the Android plugin gets, so the reminder and
/// daily list schedulers work unchanged on top of it.
class TimedNotifications implements NotificationsApi {
  TimedNotifications(
    this._browser, {
    FiredLog? fired,
    DateTime Function()? now,
    StartTimer? startTimer,
  }) : _fired = fired ?? MemoryFiredLog(),
       _now = now ?? DateTime.now,
       _startTimer = startTimer ?? Timer.new;

  /// How late a notification may still be shown: one due while no tab was
  /// open, or while the computer slept, shows on the next chance within
  /// this; an older one is dropped rather than arriving stale.
  static const missedWindow = Duration(minutes: 10);

  /// The longest the timer is set for. Browsers cap a timeout at about 24
  /// days, and a wake-up now and then puts a slept-through timer right.
  static const maxWait = Duration(hours: 1);

  /// How long a shown notification is remembered in the fired log.
  static const _remembered = Duration(days: 1);

  final BrowserNotifications _browser;
  final FiredLog _fired;
  final DateTime Function() _now;
  final StartTimer _startTimer;

  final _pending = <int, _Pending>{};
  void Function(String? payload)? _onTap;
  Timer? _timer;

  static String tagFor(int id) => 'nemo-$id';

  @override
  Future<void> initialize({void Function(String? payload)? onTap}) async =>
      _onTap = onTap;

  @override
  Future<bool> requestPermission() async =>
      await _browser.requestPermission() == BrowserPermission.granted;

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
    String channelId = 'reminders',
    List<String>? lines,
    String? payload,
  }) async {
    _pending[id] = _Pending(
      title: title,
      body: lines == null ? body : lines.join('\n'),
      at: epochMs,
      payload: payload,
    );
    _tick();
  }

  @override
  Future<void> cancel(int id) async {
    _pending.remove(id);
    _browser.close(tagFor(id));
    _tick();
  }

  /// A web page is never started by a notification: a click reaches an
  /// open tab through `onTap`.
  @override
  Future<String?> launchPayload() async => null;

  /// Shows what is due, then sets the timer for what is next.
  void _tick() {
    _timer?.cancel();
    _timer = null;
    final now = _now().millisecondsSinceEpoch;
    final due = [
      for (final MapEntry(:key, :value) in _pending.entries)
        if (value.at <= now) key,
    ];
    if (due.isNotEmpty) {
      final log = _readLog(now);
      for (final id in due) {
        final entry = _pending.remove(id)!;
        if (now - entry.at > missedWindow.inMilliseconds) continue;
        _show(id, entry, log);
      }
      _fired.write(jsonEncode(log));
    }
    if (_pending.isEmpty) return;
    final next = _pending.values.map((p) => p.at).reduce(min);
    final wait = Duration(
      milliseconds: min(next - now, maxWait.inMilliseconds),
    );
    _timer = _startTimer(wait, _tick);
  }

  void _show(int id, _Pending entry, Map<String, int> log) {
    if (_browser.permission.value != BrowserPermission.granted) return;
    // Read just now, so another tab that showed this a moment ago is seen.
    final key = '$id@${entry.at}';
    if (log.containsKey(key)) return;
    log[key] = entry.at;
    _browser.show(
      tag: tagFor(id),
      title: entry.title,
      body: entry.body,
      onClick: () => _onTap?.call(entry.payload),
    );
  }

  /// The fired log without entries older than [_remembered]; an unreadable
  /// one counts as empty.
  Map<String, int> _readLog(int now) {
    final raw = _fired.read();
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (value is int && now - value <= _remembered.inMilliseconds)
            key: value,
      };
    } on FormatException {
      return {};
    }
  }
}

class _Pending {
  const _Pending({
    required this.title,
    required this.body,
    required this.at,
    required this.payload,
  });

  final String title;
  final String body;
  final int at;
  final String? payload;
}
