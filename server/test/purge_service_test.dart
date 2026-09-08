import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';

void main() {
  late ServerDatabase db;
  late SyncService sync;
  late HlcClock dev;
  late DateTime now;

  Future<String> user(String name) async {
    final auth = AuthService(db, allowSignup: true, bcryptRounds: 4);
    return (await auth.signup(name, 'password123')).user.id;
  }

  Future<SyncResponse> push(
    String userId,
    List<SyncChange> changes, {
    int cursor = 0,
  }) async => (await sync.sync(
    userId,
    SyncRequest(cursor: cursor, changes: changes),
  )).response;

  PurgeService purge() => PurgeService(db, now: () => now);

  /// A device whose stamps sit [ago] before the wall clock the purge reads.
  ///
  /// Rows are seeded with [ancient] and deleted with a later one, because a
  /// tombstone stamped before the row it deletes loses the merge and never
  /// lands -- which is correct, and makes for a confusing test.
  HlcClock longAgo(String node, Duration ago) =>
      HlcClock(node: node, now: () => now.subtract(ago));

  setUp(() {
    db = ServerDatabase.memory();
    now = fixedNow;
    sync = SyncService(
      db,
      now: () => now,
      clock: HlcClock(node: 'srv', now: () => now),
    );
    dev = longAgo('dev', const Duration(days: 90));
  });
  tearDown(() => db.close());

  test('leaves live rows and recent tombstones alone', () async {
    final ben = await user('ben');
    final recent = longAgo('dev', const Duration(days: 3));
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.task(
        task('t2', 'l1', recent).copyWith(
          deletedAt: recent.now().toString(),
          updatedAt: recent.now().toString(),
        ),
      ),
    ]);

    final report = await purge().purge();

    expect(report.total, 0);
    expect(await db.taskById('t1'), isNotNull);
    expect(
      await db.taskById('t2'),
      isNotNull,
      reason: 'three days is not thirty',
    );
  });

  test('removes an old tombstone and everything under it', () async {
    final ben = await user('ben');
    final old = longAgo('dev', const Duration(days: 40));
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.subtask(subtask('s1', 't1', dev)),
    ]);
    // The task goes; its subtask is merely orphaned, the way the app leaves
    // it when a single task is deleted.
    await push(ben, [
      SyncChange.task(
        task('t1', 'l1', old).copyWith(
          deletedAt: old.now().toString(),
          updatedAt: old.now().toString(),
        ),
      ),
    ]);

    final report = await purge().purge();

    expect(report.tasks, 1);
    expect(report.subtasks, 1, reason: 'a subtask cannot outlive its task');
    expect(await db.taskById('t1'), isNull);
    expect(await db.subtaskById('s1'), isNull);
    expect(await db.listById('l1'), isNotNull);
  });

  test('a device that never saw the delete is told to drop the row', () async {
    final ben = await user('ben');
    final old = longAgo('dev', const Duration(days: 40));
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    // A phone that synced here, and then went in a drawer.
    final stale = await push(ben, []);

    await push(ben, [
      SyncChange.task(
        task('t1', 'l1', old).copyWith(
          deletedAt: old.now().toString(),
          updatedAt: old.now().toString(),
        ),
      ),
    ]);
    expect((await purge().purge()).tasks, 1);

    // It comes back and syncs from the cursor it still holds. Without a
    // revoke in the log it would hear nothing, keep its live copy, and push
    // the task back into existence on its next edit.
    final caughtUp = await push(ben, [], cursor: stale.cursor);
    expect(
      caughtUp.changes.whereType<SyncChangeRevoke>().map((c) => c.id),
      contains('t1'),
    );
  });

  test('purging a list takes its tasks and subtasks with it', () async {
    final ben = await user('ben');
    final old = longAgo('dev', const Duration(days: 40));
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.subtask(subtask('s1', 't1', dev)),
    ]);
    await push(ben, [
      SyncChange.list(
        list('l1', old).copyWith(
          deletedAt: old.now().toString(),
          updatedAt: old.now().toString(),
        ),
      ),
    ]);

    final report = await purge().purge();

    expect((report.lists, report.tasks, report.subtasks), (1, 1, 1));
    expect(await db.listById('l1'), isNull);
    expect(await db.taskById('t1'), isNull);
    expect(await db.subtaskById('s1'), isNull);
  });

  test('a dry run counts without deleting', () async {
    final ben = await user('ben');
    final old = longAgo('dev', const Duration(days: 40));
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    await push(ben, [
      SyncChange.task(
        task('t1', 'l1', old).copyWith(
          deletedAt: old.now().toString(),
          updatedAt: old.now().toString(),
        ),
      ),
    ]);

    expect((await purge().purge(dryRun: true)).tasks, 1);
    expect(await db.taskById('t1'), isNotNull);
    expect((await purge().purge()).tasks, 1);
    expect(await db.taskById('t1'), isNull);
  });

  test('the retention window is adjustable', () async {
    final ben = await user('ben');
    final week = longAgo('dev', const Duration(days: 8));
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    await push(ben, [
      SyncChange.task(
        task('t1', 'l1', week).copyWith(
          deletedAt: week.now().toString(),
          updatedAt: week.now().toString(),
        ),
      ),
    ]);

    expect((await purge().purge()).total, 0);
    final report = await purge().purge(retention: const Duration(days: 7));
    expect(report.tasks, 1);
  });

  test('purging twice leaves nothing to do and no log growth', () async {
    final ben = await user('ben');
    final old = longAgo('dev', const Duration(days: 40));
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    await push(ben, [
      SyncChange.task(
        task('t1', 'l1', old).copyWith(
          deletedAt: old.now().toString(),
          updatedAt: old.now().toString(),
        ),
      ),
    ]);

    await purge().purge();
    final entries = (await db.select(db.syncLog).get()).length;
    expect((await purge().purge()).total, 0);
    expect((await db.select(db.syncLog).get()).length, entries);
  });
}
