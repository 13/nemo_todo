import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/quick_add_parser.dart';

void main() {
  // A Monday.
  final now = DateTime(2026, 9, 7, 10);

  QuickAdd parse(String text, [String locale = 'en']) =>
      parseQuickAdd(text, now: now, locale: locale);

  test('a plain title is just a title', () {
    final q = parse('Water the plants');
    expect(q.title, 'Water the plants');
    expect(q.dueAt, isNull);
    expect(q.priority, isNull);
    expect(q.tags, isEmpty);
  });

  test('tags, priority and a trailing date word are taken out', () {
    final q = parse('Milk #Shop !high #dairy tomorrow');
    expect(q.title, 'Milk');
    expect(q.tags, ['shop', 'dairy']);
    expect(q.priority, 3);
    expect(q.dueAt, dayStartMsFrom(now, 1));
    expect(parse('Report !2').priority, 2);
    expect(parse('Call mom today').dueAt, dayStartMsFrom(now, 0));
  });

  test('a weekday is the next one to come', () {
    expect(parse('Bins friday').dueAt, dayStartMsFrom(now, 4));
    // Today is Monday, so "monday" is a week away rather than today.
    expect(parse('Standup Monday').dueAt, dayStartMsFrom(now, 7));
  });

  test('tomorrow and weekdays land on midnight across a clock change', () {
    // Europe's clocks go back on Sunday 25 October 2026; run with
    // TZ=Europe/Berlin to exercise the change.
    final sunday = DateTime(2026, 10, 25, 10);
    DateTime? due(String text) {
      final ms = parseQuickAdd(text, now: sunday, locale: 'en').dueAt;
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }

    expect(due('Milk tomorrow'), DateTime(2026, 10, 26));
    expect(due('Bins friday'), DateTime(2026, 10, 30));
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        parseQuickAdd(
          'Milk tomorrow',
          now: DateTime(2026, 3, 29, 10),
          locale: 'en',
        ).dueAt!,
      ),
      DateTime(2026, 3, 30),
    );
  }, tags: 'dst');

  test('a date word inside the title is part of the title', () {
    final q = parse('Buy the Sunday paper');
    expect(q.title, 'Buy the Sunday paper');
    expect(q.dueAt, isNull);
  });

  test('nothing is taken that would leave no title', () {
    final q = parse('tomorrow');
    expect(q.title, 'tomorrow');
    expect(q.dueAt, isNull);
    expect(parse('#shop').title, '#shop');
    expect(parse('!high').title, '!high');
  });

  test('unknown markers stay in the title', () {
    expect(parse('Say hi !loud').title, 'Say hi !loud');
    expect(parse('Say hi !loud').priority, isNull);
  });

  test('date words are read in the app language only', () {
    expect(parse('Arzt morgen', 'de').dueAt, dayStartMsFrom(now, 1));
    expect(parse('Arzt morgen', 'de').title, 'Arzt');
    expect(parse('Good morgen').dueAt, isNull, reason: 'not an English word');
    expect(parse('Pane domani !alta', 'it').priority, 3);
    expect(parse('Pane venerdi', 'it_IT').dueAt, dayStartMsFrom(now, 4));
    expect(parse('Bins friday', 'fr').dueAt, dayStartMsFrom(now, 4));
  });
}
