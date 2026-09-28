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

/// How many distinct notification ids the daily list cycles through: today
/// plus the [dailyDigestDays] scheduled ahead, so today's id never collides
/// with a later morning's.
const dailyDigestSlots = 8;
const dailyDigestChannelId = 'daily_list';

/// Where a tap on the daily list goes: `Routes.today`, spelled out so this
/// file does not pull in the router and every screen with it.
const dailyDigestPayload = '/today';

/// Notification id for [day]'s morning, keyed by [day]'s local calendar
/// date rather than its position among the scheduled mornings. That way a
/// refresh that runs after today's notification has already fired -- or
/// while it is still showing -- lands on the same id every time, instead of
/// today's list shifting to whatever id "tomorrow" used yesterday.
///
/// Negative, so it never meets a reminder's, which are
/// `hashCode & 0x7fffffff`. `%` in Dart is the always-non-negative Euclidean
/// modulo, so this holds for any date, not just ones after 1970.
int dailyDigestId(DateTime day) {
  final dayNumber = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(1970)).inDays;
  return -(1 + dayNumber % dailyDigestSlots);
}

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
    final s = settings();
    final now = _now();
    final todayId = dailyDigestId(_day(now, 0));

    if (!s.enabled) {
      // Today's list included: switching off means no more notification at
      // all, even the one already showing.
      for (var i = 0; i < dailyDigestSlots; i++) {
        await _api.cancel(dailyDigestId(_day(now, i)));
      }
      return;
    }

    final first = _morning(now, 0, s.minutes).isAfter(now) ? 0 : 1;
    // Cancel every slot this cycle could touch, except today's once its
    // time has passed: cancelling it would also pull an already-showing
    // notification out of the shade, and nothing here is going to
    // reschedule it (the loop below starts at `first`, which skips today
    // in that case).
    for (var i = 0; i < dailyDigestSlots; i++) {
      final id = dailyDigestId(_day(now, i));
      if (first == 1 && id == todayId) continue;
      await _api.cancel(id);
    }
    final tasks = await loadTasks();
    for (var i = 0; i < dailyDigestDays; i++) {
      final fireAt = _morning(now, first + i, s.minutes);
      final digest = buildDigest(tasks, fireAt);
      if (digest == null) continue;
      await _api.scheduleAt(
        id: dailyDigestId(_day(now, first + i)),
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

  /// [now]'s calendar date, [days] later. Built from calendar fields, like
  /// [_morning], so it lands on the right date across a daylight-saving
  /// change instead of drifting by an hour through `Duration` arithmetic.
  static DateTime _day(DateTime now, int days) =>
      DateTime(now.year, now.month, now.day + days);
}
