import 'dart:io';

import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';

/// A [BlobStore] whose `delete` throws for one chosen hash, as if that file
/// could not be removed (permissions, a busy disk) -- the failure a real
/// sweep must survive without losing the rest of the orphans or the row
/// purge running alongside it.
class _FlakyBlobStore extends BlobStore {
  _FlakyBlobStore(super.root, this.failing);

  final String failing;

  @override
  Future<void> delete(String sha256) {
    if (sha256 == failing) {
      throw const FileSystemException('permission denied', 'x');
    }
    return super.delete(sha256);
  }
}

void main() {
  late ServerDatabase db;
  late SyncService sync;
  late HlcClock dev;
  late DateTime now;
  late Directory blobRoot;
  late BlobStore defaultStore;

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

  PurgeService purge({BlobStore? blobs}) =>
      PurgeService(db, blobs: blobs ?? defaultStore, now: () => now);

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
    blobRoot = Directory.systemTemp.createTempSync('nemo-purge-default');
    defaultStore = BlobStore(blobRoot.path);
  });
  tearDown(() async {
    await db.close();
    blobRoot.deleteSync(recursive: true);
  });

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

  test(
    'a purged task takes its photos, and orphaned bytes are swept',
    () async {
      final root = Directory.systemTemp.createTempSync('nemo-purge-blobs');
      addTearDown(() => root.deleteSync(recursive: true));
      final store = BlobStore(root.path);

      String stamp(Duration ago) => Hlc(
        millis: now.subtract(ago).millisecondsSinceEpoch,
        counter: 0,
        node: 'a',
      ).toString();
      final old = stamp(const Duration(days: 60));
      final live = stamp(Duration.zero);

      await db
          .into(db.lists)
          .insert(
            TaskList(
              id: 'l1',
              name: 'L',
              sortKey: 'V',
              updatedAt: live,
            ).toInsertable(),
          );
      await db
          .into(db.tasks)
          .insert(
            Task(
              id: 't1',
              listId: 'l1',
              title: 'T',
              sortKey: 'V',
              updatedAt: old,
              deletedAt: old,
            ).toInsertable(),
          );
      await db
          .into(db.photos)
          .insert(
            Photo(
              id: 'p1',
              taskId: 't1',
              sha256: 'a' * 64,
              byteSize: 3,
              width: 1,
              height: 1,
              sortKey: 'V',
              updatedAt: old,
            ).toInsertable(),
          );

      Future<void> blob(String hash, Duration ago) async {
        await store.write(hash, [1, 2, 3]);
        await db
            .into(db.blobs)
            .insert(
              BlobsCompanion.insert(
                sha256: hash,
                byteSize: 3,
                ownerUserId: 'u1',
                createdAt: now.subtract(ago).millisecondsSinceEpoch,
              ),
            );
      }

      await blob(
        'a' * 64,
        const Duration(days: 60),
      ); // held by p1, until p1 goes
      await blob('b' * 64, const Duration(days: 60)); // orphaned and old: swept
      await blob('c' * 64, const Duration(days: 1)); // an upload mid-flight

      final report = await purge(blobs: store).purge();

      expect(report.photos, 1);
      expect(report.blobs, 2);
      expect(await db.photoById('p1'), isNull);
      expect(await store.exists('a' * 64), isFalse);
      expect(await store.exists('b' * 64), isFalse);
      expect(
        await store.exists('c' * 64),
        isTrue,
        reason:
            'bytes uploaded a moment ago are waiting for the row that '
            'will name them',
      );
      final logged = await (db.select(
        db.syncLog,
      )..where((t) => t.entity.equals('photo'))).get();
      expect(logged.single.op, 'revoke');
    },
  );

  test('a blob that fails to delete keeps its row, without blocking the rest '
      'of the sweep or the row purge running alongside it', () async {
    final root = Directory.systemTemp.createTempSync('nemo-purge-blobs');
    addTearDown(() => root.deleteSync(recursive: true));
    final good = 'd' * 64;
    final bad = 'e' * 64;
    final flaky = _FlakyBlobStore(root.path, bad);

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

    Future<void> blob(String hash) async {
      await flaky.write(hash, [1, 2, 3]);
      await db
          .into(db.blobs)
          .insert(
            BlobsCompanion.insert(
              sha256: hash,
              byteSize: 3,
              ownerUserId: 'u1',
              createdAt: now
                  .subtract(const Duration(days: 60))
                  .millisecondsSinceEpoch,
            ),
          );
    }

    await blob(good);
    await blob(bad);

    final report = await purge(blobs: flaky).purge();

    expect(
      report.tasks,
      1,
      reason:
          'a file that will not delete must not roll back the row '
          'purge committing alongside it',
    );
    expect(await db.taskById('t1'), isNull);
    expect(
      report.blobs,
      1,
      reason: 'only the blob actually removed is counted',
    );
    expect(await flaky.exists(good), isFalse);
    expect(
      await flaky.exists(bad),
      isTrue,
      reason: 'the failing delete left the file behind',
    );
    final goodRow = await (db.select(
      db.blobs,
    )..where((t) => t.sha256.equals(good))).getSingleOrNull();
    expect(goodRow, isNull);
    final badRow = await (db.select(
      db.blobs,
    )..where((t) => t.sha256.equals(bad))).getSingleOrNull();
    expect(
      badRow,
      isNotNull,
      reason: 'its row is kept so a later sweep retries it',
    );
  });

  test(
    'a dry run predicts the same blobs count a real run would sweep',
    () async {
      final root = Directory.systemTemp.createTempSync('nemo-purge-blobs');
      addTearDown(() => root.deleteSync(recursive: true));
      final store = BlobStore(root.path);

      String stamp(Duration ago) => Hlc(
        millis: now.subtract(ago).millisecondsSinceEpoch,
        counter: 0,
        node: 'a',
      ).toString();
      final old = stamp(const Duration(days: 60));
      final live = stamp(Duration.zero);

      await db
          .into(db.lists)
          .insert(
            TaskList(
              id: 'l1',
              name: 'L',
              sortKey: 'V',
              updatedAt: live,
            ).toInsertable(),
          );
      await db
          .into(db.tasks)
          .insert(
            Task(
              id: 't1',
              listId: 'l1',
              title: 'T',
              sortKey: 'V',
              updatedAt: old,
              deletedAt: old,
            ).toInsertable(),
          );
      await db
          .into(db.photos)
          .insert(
            Photo(
              id: 'p1',
              taskId: 't1',
              sha256: 'a' * 64,
              byteSize: 3,
              width: 1,
              height: 1,
              sortKey: 'V',
              updatedAt: old,
            ).toInsertable(),
          );

      Future<void> blob(String hash, Duration ago) async {
        await store.write(hash, [1, 2, 3]);
        await db
            .into(db.blobs)
            .insert(
              BlobsCompanion.insert(
                sha256: hash,
                byteSize: 3,
                ownerUserId: 'u1',
                createdAt: now.subtract(ago).millisecondsSinceEpoch,
              ),
            );
      }

      // Orphaned only once this run's own purge of p1 lands -- exactly the
      // undercount a dry run must not fall into.
      await blob('a' * 64, const Duration(days: 60));
      // Already orphaned before this run starts.
      await blob('b' * 64, const Duration(days: 60));

      final dryReport = await purge(blobs: store).purge(dryRun: true);
      expect(
        dryReport.blobs,
        2,
        reason:
            'a dry run predicts what the photo purge below would newly '
            'orphan, not only what is orphaned already',
      );
      expect(await store.exists('a' * 64), isTrue);
      expect(await store.exists('b' * 64), isTrue);
      expect(await db.photoById('p1'), isNotNull);

      final report = await purge(blobs: store).purge();
      expect(report.blobs, dryReport.blobs);
    },
  );
}
