import 'package:intl/intl.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';

/// "Today", "Tomorrow", "In 3 days", "Mon, 14 Sep" … plus the time when set.
String dueLabel(
  L l,
  String locale, {
  required int dueAt,
  required bool hasTime,
  required DateTime now,
}) {
  final days = daysFromToday(dueAt, now);
  final day = switch (days) {
    0 => l.dateToday,
    1 => l.dateTomorrow,
    -1 => l.dateYesterday,
    > 1 && < 7 => l.dateInDays(days),
    < -1 && > -7 => l.dateDaysAgo(-days),
    _ => DateFormat.MMMEd(
      locale,
    ).format(DateTime.fromMillisecondsSinceEpoch(dueAt)),
  };
  if (!hasTime) return day;
  final time = DateFormat.jm(locale)
      .format(DateTime.fromMillisecondsSinceEpoch(dueAt));
  return '$day · $time';
}

/// Section header for a calendar day: "Tomorrow" or "Tue, 9 Sep".
String dayHeader(L l, String locale, DateTime day, DateTime now) {
  final days = daysFromToday(day.millisecondsSinceEpoch, now);
  return switch (days) {
    0 => l.dateToday,
    1 => l.dateTomorrow,
    _ => DateFormat.MMMEd(locale).format(day),
  };
}

String timeLabel(String locale, int dueAt) =>
    DateFormat.jm(locale).format(DateTime.fromMillisecondsSinceEpoch(dueAt));

String longDate(String locale, DateTime day) =>
    DateFormat.yMMMMEEEEd(locale).format(day);

/// The name of a day: "Friday", "Freitag", "venerdì".
String weekdayName(String locale, DateTime day) =>
    DateFormat.EEEE(locale).format(day);
