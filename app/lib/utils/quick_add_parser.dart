import 'package:meta/meta.dart';
import 'package:nemo/utils/dates.dart';

/// What a quick-add line says beyond its title.
@immutable
class QuickAdd {
  const QuickAdd({
    required this.title,
    this.dueAt,
    this.priority,
    this.tags = const [],
  });

  final String title;

  /// Local midnight of the day a date word named, or null.
  final int? dueAt;

  /// 1 to 3 when a `!` marker set one, else null.
  final int? priority;
  final List<String> tags;
}

/// Reads `Milk tomorrow #shop !high` as a task titled "Milk", due tomorrow,
/// tagged `shop`, at high priority.
///
/// - `#word` anywhere is a tag, written the way the task screen writes one.
/// - `!1` `!2` `!3`, or `!low` `!medium` `!high` in the app's language, is a
///   priority.
/// - A date word counts only at the very end of the title: "today",
///   "tomorrow", or a weekday meaning the next one to come. At the end only,
///   because "Buy the Sunday paper" is a title, not a due date.
///
/// Date words are read in the app's language, not every language at once:
/// German "morgen" is "tomorrow", and nothing in an English title should be
/// taken for it. Whatever would leave the title empty is left alone, so a
/// task called "Tomorrow" can still be written.
QuickAdd parseQuickAdd(
  String input, {
  required DateTime now,
  required String locale,
}) {
  final words = _vocabulary[locale.split(RegExp('[_-]')).first] ?? _english;
  final tags = <String>[];
  int? priority;
  final rest = <String>[];

  for (final token in input.trim().split(RegExp(r'\s+'))) {
    if (token.length > 1 && token.startsWith('#')) {
      final tag = token.substring(1).toLowerCase();
      if (!tags.contains(tag)) tags.add(tag);
      continue;
    }
    if (token.length > 1 && token.startsWith('!')) {
      final level = words.priorities[token.substring(1).toLowerCase()];
      if (level != null) {
        priority = level;
        continue;
      }
    }
    if (token.isNotEmpty) rest.add(token);
  }

  int? dueAt;
  if (rest.length > 1) {
    final days = _daysFor(rest.last.toLowerCase(), words, now);
    if (days != null) {
      dueAt = dayStartMsFrom(now, days);
      rest.removeLast();
    }
  }

  final title = rest.join(' ');
  if (title.isEmpty) return QuickAdd(title: input.trim());
  return QuickAdd(title: title, dueAt: dueAt, priority: priority, tags: tags);
}

/// Days from [now] to the day [word] names, or null if it names none.
int? _daysFor(String word, _Words words, DateTime now) {
  final fixed = words.days[word];
  if (fixed != null) return fixed;
  final weekday = words.weekdays[word];
  if (weekday == null) return null;
  // The next one to come: naming today's weekday means a week from now.
  final ahead = (weekday - now.weekday) % 7;
  return ahead == 0 ? 7 : ahead;
}

class _Words {
  const _Words({
    required this.days,
    required this.weekdays,
    required this.priorities,
  });

  final Map<String, int> days;
  final Map<String, int> weekdays;
  final Map<String, int> priorities;
}

const _numbers = {'1': 1, '2': 2, '3': 3};

const _english = _Words(
  days: {'today': 0, 'tomorrow': 1},
  weekdays: {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  },
  priorities: {..._numbers, 'low': 1, 'medium': 2, 'med': 2, 'high': 3},
);

const Map<String, _Words> _vocabulary = {
  'en': _english,
  'de': _Words(
    days: {'heute': 0, 'morgen': 1, 'übermorgen': 2},
    weekdays: {
      'montag': DateTime.monday,
      'dienstag': DateTime.tuesday,
      'mittwoch': DateTime.wednesday,
      'donnerstag': DateTime.thursday,
      'freitag': DateTime.friday,
      'samstag': DateTime.saturday,
      'sonntag': DateTime.sunday,
    },
    priorities: {..._numbers, 'niedrig': 1, 'mittel': 2, 'hoch': 3},
  ),
  'it': _Words(
    days: {'oggi': 0, 'domani': 1, 'dopodomani': 2},
    weekdays: {
      'lunedì': DateTime.monday,
      'lunedi': DateTime.monday,
      'martedì': DateTime.tuesday,
      'martedi': DateTime.tuesday,
      'mercoledì': DateTime.wednesday,
      'mercoledi': DateTime.wednesday,
      'giovedì': DateTime.thursday,
      'giovedi': DateTime.thursday,
      'venerdì': DateTime.friday,
      'venerdi': DateTime.friday,
      'sabato': DateTime.saturday,
      'domenica': DateTime.sunday,
    },
    priorities: {..._numbers, 'bassa': 1, 'media': 2, 'alta': 3},
  ),
};
