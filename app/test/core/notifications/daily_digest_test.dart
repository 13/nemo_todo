import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/daily_digest.dart';
import 'package:nemo_core/nemo_core.dart';

void main() {
  final fireAt = DateTime(2026, 9, 28, 8);

  Task task(
    String title,
    DateTime? due, {
    bool done = false,
    String? deletedAt,
  }) => Task(
    id: title,
    listId: 'l',
    title: title,
    sortKey: 'V',
    updatedAt: '0000000000001-0000-n',
    dueAt: due?.millisecondsSinceEpoch,
    done: done,
    deletedAt: deletedAt,
  );

  test('nothing due gives no digest', () {
    expect(buildDigest([], fireAt), isNull);
    expect(
      buildDigest([task('Later', DateTime(2026, 9, 29, 9))], fireAt),
      isNull,
    );
  });

  test('counts today and overdue, overdue first', () {
    final digest = buildDigest([
      task('Old', DateTime(2026, 9, 26)),
      task('Morning', DateTime(2026, 9, 28, 7)),
      task('Yesterday', DateTime(2026, 9, 27, 18)),
      task('Evening', DateTime(2026, 9, 28, 19)),
      task('All day', DateTime(2026, 9, 28)),
    ], fireAt)!;
    expect(digest.overdueCount, 2);
    expect(digest.todayCount, 3);
    expect(digest.lines, ['Old', 'Yesterday', 'Morning', 'Evening', 'All day']);
    expect(digest.more, 0);
  });

  test('leaves out done, deleted and undated tasks', () {
    final digest = buildDigest([
      task('Done', DateTime(2026, 9, 28, 9), done: true),
      task('Deleted', DateTime(2026, 9, 28, 9), deletedAt: 'x'),
      task('Undated', null),
      task('Kept', DateTime(2026, 9, 28, 9)),
    ], fireAt)!;
    expect(digest.lines, ['Kept']);
  });

  test('caps the lines at six and counts the rest', () {
    final digest = buildDigest([
      for (var i = 0; i < 9; i++) task('T$i', DateTime(2026, 9, 28, 9)),
    ], fireAt)!;
    expect(digest.lines, hasLength(digestMaxLines));
    expect(digest.more, 3);
  });

  test("a task due tomorrow is only in tomorrow's digest", () {
    final tasks = [task('Tomorrow', DateTime(2026, 9, 29, 9))];
    expect(buildDigest(tasks, fireAt), isNull);
    final next = buildDigest(tasks, DateTime(2026, 9, 29, 8))!;
    expect(next.todayCount, 1);
    final after = buildDigest(tasks, DateTime(2026, 9, 30, 8))!;
    expect(after.overdueCount, 1);
  });
}
