import 'package:flutter/foundation.dart';
import 'package:nemo/core/notifications/daily_digest.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo_core/nemo_core.dart';

/// Whether the daily list is on, and when: minutes after local midnight.
class DailyListSettings {
  const DailyListSettings({required this.enabled, required this.minutes});
  final bool enabled;
  final int minutes;
}

/// Daily list text, from the device locale like the reminder channel's.
class DigestStrings {
  const DigestStrings({
    required this.channelName,
    required this.channelDescription,
    required this.title,
    required this.more,
  });

  final String channelName;
  final String channelDescription;
  final String Function(int today, int overdue) title;
  final String Function(int count) more;
}

/// How many mornings are scheduled ahead, so the list keeps coming on days
/// the app is not opened.
const dailyDigestDays = 7;
const dailyDigestChannelId = 'daily_list';

/// Where a tap on the daily list goes: `Routes.today`, spelled out so this
/// file does not pull in the router and every screen with it.
const dailyDigestPayload = '/today';

/// Notification id of the [day]th scheduled morning. Negative, so it never
/// meets a reminder's, which are `hashCode & 0x7fffffff`.
int dailyDigestId(int day) => -(day + 1);

abstract interface class DailyDigestScheduler {
  /// Replaces the scheduled mornings with ones built from current data.
  Future<void> refresh();
}

/// Web and tests: there is no daily list.
class NoopDailyDigestScheduler implements DailyDigestScheduler {
  const NoopDailyDigestScheduler();

  @override
  Future<void> refresh() async {}
}

class AndroidDailyDigestScheduler implements DailyDigestScheduler {
  AndroidDailyDigestScheduler(
    this._api, {
    required this.loadTasks,
    required this.settings,
    required this.strings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsApi _api;
  final Future<List<Task>> Function() loadTasks;
  final DailyListSettings Function() settings;
  final DigestStrings strings;
  final DateTime Function() _now;

  Future<void>? _running;
  var _again = false;

  /// Runs one rebuild at a time; a call while one runs asks for one more
  /// afterwards, so the last change always wins without piling up.
  @override
  Future<void> refresh() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    do {
      _again = false;
      try {
        await _rebuild();
        // A notification that cannot be scheduled must not take a task
        // write or a setting down with it.
      } on Object catch (error) {
        debugPrint('Daily list not scheduled: $error');
      }
    } while (_again);
  }

  Future<void> _rebuild() async {
    for (var i = 0; i < dailyDigestDays; i++) {
      await _api.cancel(dailyDigestId(i));
    }
    final s = settings();
    if (!s.enabled) return;
    final now = _now();
    final first = _morning(now, 0, s.minutes).isAfter(now) ? 0 : 1;
    final tasks = await loadTasks();
    for (var i = 0; i < dailyDigestDays; i++) {
      final fireAt = _morning(now, first + i, s.minutes);
      final digest = buildDigest(tasks, fireAt);
      if (digest == null) continue;
      await _api.scheduleAt(
        id: dailyDigestId(i),
        title: strings.title(digest.todayCount, digest.overdueCount),
        body: digest.lines.join(', '),
        lines: [
          ...digest.lines,
          if (digest.more > 0) strings.more(digest.more),
        ],
        epochMs: fireAt.millisecondsSinceEpoch,
        channelId: dailyDigestChannelId,
        channelName: strings.channelName,
        channelDescription: strings.channelDescription,
        payload: dailyDigestPayload,
      );
    }
  }

  /// [minutes] after local midnight, [days] after [now]'s day. Built from
  /// calendar fields, so a daylight-saving change keeps the wall-clock time.
  static DateTime _morning(DateTime now, int days, int minutes) => DateTime(
    now.year,
    now.month,
    now.day + days,
    minutes ~/ 60,
    minutes % 60,
  );
}
