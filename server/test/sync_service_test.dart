import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';

void main() {
  late ServerDatabase db;
  late SyncService sync;
  late HlcClock dev;

  Future<String> user(String name) async {
    final auth = AuthService(db, allowSignup: true, bcryptRounds: 4);
    return (await auth.signup(name, 'password123')).user.id;
  }

  // A client of this release, unless a test says otherwise.
  Future<SyncResponse> push(
    String userId,
    List<SyncChange> changes, {
    int cursor = 0,
    bool photos = true,
  }) async => (await sync.sync(
    userId,
    SyncRequest(cursor: cursor, changes: changes, photos: photos),
  )).response;

  /// Every page from [cursor] on, pulled the way a client does.
  Future<({List<String> changes, List<(int, bool)> pages})> pullAll(
    String userId, {
    required bool photos,
  }) async {
    final changes = <String>[];
    final pages = <(int, bool)>[];
    var cursor = 0;
    var hasMore = true;
    while (hasMore) {
      final r = await push(userId, [], cursor: cursor, photos: photos);
      changes.addAll(
        r.changes.map(
          (c) =>
              '${c is SyncChangeRevoke ? 'revoke' : 'upsert'}:'
              '${c.entity.name}:${c.rowId}',
        ),
      );
      pages.add((r.cursor, r.hasMore));
      cursor = r.cursor;
      hasMore = r.hasMore;
    }
    return (changes: changes, pages: pages);
  }

  /// Another device of ben's creates, tombstones and moves a photo, then
  /// adds a task with a photo, so the log ends on a photo entry.
  ///
  /// Live log entries afterwards: 1 list l1, 2 list l2, 6 revoke t1,
  /// 7 revoke p1, 8 upsert t1, 9 upsert p1, 10 upsert t2, 11 upsert p2.
  Future<String> photoHistory() async {
    final ben = await user('ben');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.list(list('l2', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.photo(photo('p1', 't1', dev)),
    ]);
    final stamp = dev.now().toString();
    await push(ben, [
      SyncChange.photo(
        photo('p1', 't1', dev).copyWith(updatedAt: stamp, deletedAt: stamp),
      ),
    ]);
    await push(ben, [SyncChange.task(task('t1', 'l2', dev))]);
    await push(ben, [
      SyncChange.task(task('t2', 'l1', dev)),
      SyncChange.photo(photo('p2', 't2', dev)),
    ]);
    return ben;
  }

  test(
    'a client that cannot read photos gets everything else, and moves on',
    () async {
      final ben = await photoHistory();

      final all = await pullAll(ben, photos: false);
      expect(all.changes, [
        'upsert:list:l1',
        'upsert:list:l2',
        'revoke:task:t1',
        'upsert:task:t1',
        'upsert:task:t2',
      ]);
      expect(all.pages, [
        (11, false),
      ], reason: 'the cursor passes the photo entries it skipped');

      // Paged, the limit counts what is sent, and the last page still
      // carries the cursor past the trailing photo.
      sync = SyncService(
        db,
        now: () => fixedNow,
        clock: HlcClock(node: 'srv', now: () => fixedNow),
        pageSize: 2,
      );
      final paged = await pullAll(ben, photos: false);
      expect(paged.changes, all.changes);
      expect(paged.pages, [(2, true), (8, true), (11, false)]);

      final caughtUp = await push(ben, [], cursor: 11, photos: false);
      expect(caughtUp.changes, isEmpty);
      expect(caughtUp.cursor, 11);
      expect(caughtUp.hasMore, isFalse);
    },
  );

  test('a client that can read photos gets them', () async {
    final ben = await photoHistory();

    final all = await pullAll(ben, photos: true);
    expect(all.changes, [
      'upsert:list:l1',
      'upsert:list:l2',
      'revoke:task:t1',
      'revoke:photo:p1',
      'upsert:task:t1',
      'upsert:photo:p1',
      'upsert:task:t2',
      'upsert:photo:p2',
    ]);
    expect(all.pages, [(11, false)]);
  });

  setUp(() {
    db = ServerDatabase.memory();
    sync = SyncService(
      db,
      now: () => fixedNow,
      clock: HlcClock(node: 'srv', now: () => fixedNow),
    );
    dev = deviceClock('dev');
  });
  tearDown(() => db.close());

  test('every response says the server takes photos', () async {
    final ben = await user('ben');
    // Asked by a client that cannot read photos too: what the server
    // accepts does not depend on what the client can read.
    expect((await push(ben, [], photos: false)).photos, isTrue);
    expect(
      (await push(ben, [SyncChange.list(list('l1', dev))])).photos,
      isTrue,
    );
  });

  test('push then pull returns rows, owner membership and cursor', () async {
    final ben = await user('ben');
    final l = list('l1', dev);
    final t = task('t1', 'l1', dev);
    final first = await push(ben, [SyncChange.list(l), SyncChange.task(t)]);
    expect(first.rejected, isEmpty);
    expect(first.changes.map((c) => c.rowId), ['l1', 't1']);
    expect((first.changes.first as SyncChangeList).row.ownerId, ben);
    expect(first.cursor, 2);
    expect(first.hasMore, isFalse);
    expect(first.members['l1'], [
      const ListMember(username: 'ben', role: MemberRole.owner),
    ]);
    expect(
      Hlc.parse(first.serverHlc).millis,
      greaterThanOrEqualTo(fixedNow.millisecondsSinceEpoch),
    );

    final again = await push(ben, [], cursor: first.cursor);
    expect(again.changes, isEmpty);
    expect(again.cursor, first.cursor);
  });

  test(
    'replaying a push is idempotent and older rows do not overwrite',
    () async {
      final ben = await user('ben');
      final l = list('l1', dev);
      final t = task('t1', 'l1', dev, title: 'v1');
      final r1 = await push(ben, [SyncChange.list(l), SyncChange.task(t)]);
      final r2 = await push(ben, [
        SyncChange.list(l),
        SyncChange.task(t),
      ], cursor: r1.cursor);
      expect(r2.changes, isEmpty, reason: 'nothing new was logged');

      final newer = t.copyWith(title: 'v2', updatedAt: dev.now().toString());
      final r3 = await push(ben, [SyncChange.task(newer)], cursor: r2.cursor);
      expect((r3.changes.single as SyncChangeTask).row.title, 'v2');
      // An exact replay stays silent, but a strictly older push is answered
      // with the row that won, so the device that sent it can correct itself.
      final r4 = await push(ben, [SyncChange.task(t)], cursor: r3.cursor);
      expect((r4.changes.single as SyncChangeTask).row.title, 'v2');
      expect(r4.rejected, isEmpty);
      expect((await db.taskById('t1'))!.title, 'v2');
    },
  );

  test('pull is paginated', () async {
    final ben = await user('ben');
    sync = SyncService(db, now: () => fixedNow, pageSize: 100);
    final changes = [
      SyncChange.list(list('l1', dev)),
      for (var i = 0; i < 150; i++) SyncChange.task(task('t$i', 'l1', dev)),
    ];
    final page1 = await push(ben, changes);
    expect(page1.changes, hasLength(100));
    expect(page1.hasMore, isTrue);
    final page2 = await push(ben, [], cursor: page1.cursor);
    expect(page2.changes, hasLength(51));
    expect(page2.hasMore, isFalse);
    expect(page2.cursor, 151);
  });

  test('rejects skewed, invalid and foreign changes', () async {
    final ben = await user('ben');
    final anna = await user('anna');
    await push(ben, [SyncChange.list(list('l1', dev))]);
    final future = HlcClock(
      node: 'x',
      now: () => fixedNow.add(const Duration(hours: 2)),
    );
    final r = await push(anna, [
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.list(list('l2', future)),
      SyncChange.list(list('l3', dev).copyWith(updatedAt: 'garbage')),
      SyncChange.subtask(subtask('s1', 'missing', dev)),
      const SyncChange.revoke(target: SyncEntity.task, id: 't9'),
    ]);
    expect(r.rejected.map((x) => '${x.rowId}:${x.reason}'), [
      't1:forbidden',
      'l2:clock_skew',
      'l3:invalid_hlc',
      's1:unknown_task',
      't9:not_allowed',
    ]);
    expect(await db.taskById('t1'), isNull);
  });

  test('editors may edit tasks but not the list row', () async {
    final ben = await user('ben');
    final anna = await user('anna');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    await MembersService(db).share(ben, 'l1', 'anna', MemberRole.editor);
    final annaDev = laterClock('anna');
    final r = await push(anna, [
      SyncChange.task(task('t1', 'l1', annaDev, title: 'edited')),
      SyncChange.subtask(subtask('s1', 't1', annaDev)),
      SyncChange.list(list('l1', annaDev, name: 'renamed')),
    ]);
    expect(r.rejected.map((x) => x.reason), ['forbidden']);
    expect(r.rejected.single.rowId, 'l1');
    expect((await db.taskById('t1'))!.title, 'edited');
    expect(await db.subtaskById('s1'), isNotNull);
    expect((await db.listById('l1'))!.name, 'List');
  });

  test(
    'moving a task revokes it from the old list ahead of the upsert',
    () async {
      final ben = await user('ben');
      final anna = await user('anna');
      await push(ben, [
        SyncChange.list(list('a', dev)),
        SyncChange.list(list('b', dev)),
        SyncChange.task(task('t1', 'a', dev)),
        SyncChange.subtask(subtask('s1', 't1', dev)),
      ]);
      await MembersService(db).share(ben, 'a', 'anna', MemberRole.editor);
      final annaBefore = await push(anna, []);
      expect(annaBefore.changes.map((c) => c.rowId), ['a', 't1', 's1']);

      final moved = (await db.taskById('t1'))!
          .copyWith(listId: 'b', updatedAt: dev.now().toString());
      final outcome = await sync.sync(
        ben,
        SyncRequest(cursor: 0, changes: [SyncChange.task(moved)]),
      );
      expect(outcome.notifyUserIds, {ben, anna});

      final annaAfter = await push(anna, [], cursor: annaBefore.cursor);
      expect(
        annaAfter.changes
            .map((c) => (c, c.rowId))
            .map(
              (p) =>
                  '${p.$1 is SyncChangeRevoke ? 'revoke' : 'upsert'}:${p.$2}',
            ),
        ['revoke:t1', 'revoke:s1'],
      );

      final benAll = await push(ben, []);
      final kinds = benAll.changes
          .map(
            (c) => '${c is SyncChangeRevoke ? 'revoke' : 'upsert'}:${c.rowId}',
          )
          .toList();
      expect(kinds.indexOf('revoke:t1'), lessThan(kinds.indexOf('upsert:t1')));
      expect((benAll.changes.last as SyncChangeSubtask).row.id, 's1');
      final back = await push(anna, [
        SyncChange.task(
          moved.copyWith(
            listId: 'a',
            updatedAt: laterClock('anna').now().toString(),
          ),
        ),
      ]);
      // Anna is no member of list b, where the task now lives.
      expect(back.rejected.single.reason, 'forbidden');
    },
  );

  test(
    'a stranger cannot pull a task back out of a list they do not belong to',
    () async {
      final ben = await user('ben');
      final anna = await user('anna');
      await push(ben, [
        SyncChange.list(list('a', dev)),
        SyncChange.task(task('t1', 'a', dev)),
      ]);
      await push(anna, [SyncChange.list(list('mine', deviceClock('anna')))]);
      final stolen = task('t1', 'mine', deviceClock('anna'));
      final r = await push(anna, [SyncChange.task(stolen)]);
      expect(r.rejected.single.reason, 'forbidden');
      expect((await db.taskById('t1'))!.listId, 'a');
    },
  );

  test(
    'a stranger cannot re-parent a subtask out of a list they do not belong to',
    () async {
      final ben = await user('ben');
      final anna = await user('anna');
      await push(ben, [
        SyncChange.list(list('a', dev)),
        SyncChange.task(task('t1', 'a', dev)),
        SyncChange.subtask(subtask('s1', 't1', dev)),
      ]);
      final annaClock = laterClock('anna');
      await push(anna, [
        SyncChange.list(list('mine', annaClock)),
        SyncChange.task(task('mt', 'mine', annaClock)),
      ]);
      final stolen = subtask('s1', 'mt', annaClock);
      final r = await push(anna, [SyncChange.subtask(stolen)]);
      expect(r.rejected.single.reason, 'forbidden');
      expect((await db.subtaskById('s1'))!.taskId, 't1');
    },
  );

  test('moving a subtask between lists revokes it from the old list', () async {
    final ben = await user('ben');
    final anna = await user('anna');
    await push(ben, [
      SyncChange.list(list('a', dev)),
      SyncChange.list(list('b', dev)),
      SyncChange.task(task('t1', 'a', dev)),
      SyncChange.task(task('t2', 'b', dev)),
      SyncChange.subtask(subtask('s1', 't1', dev)),
    ]);
    await MembersService(db).share(ben, 'a', 'anna', MemberRole.editor);
    final annaBefore = await push(anna, []);
    expect(annaBefore.changes.map((c) => c.rowId), ['a', 't1', 's1']);

    final moved = (await db.subtaskById('s1'))!
        .copyWith(taskId: 't2', updatedAt: dev.now().toString());
    final outcome = await sync.sync(
      ben,
      SyncRequest(cursor: 0, changes: [SyncChange.subtask(moved)]),
    );
    expect(outcome.notifyUserIds, {ben, anna});

    final annaAfter = await push(anna, [], cursor: annaBefore.cursor);
    expect(
      annaAfter.changes.map(
        (c) => '${c is SyncChangeRevoke ? 'revoke' : 'upsert'}:${c.rowId}',
      ),
      ['revoke:s1'],
    );
  });

  test(
    'a losing push gets the winning row back in the same response',
    () async {
      final ben = await user('ben');
      final first = await push(ben, [
        SyncChange.list(list('l1', dev)),
        SyncChange.task(task('t1', 'l1', dev)),
      ]);

      // A device that never saw the winning edit pushes an older stamp.
      final stale = task('t1', 'l1', deviceClock('old'), title: 'Stale');
      final r = await push(ben, [SyncChange.task(stale)], cursor: first.cursor);

      expect(r.rejected, isEmpty, reason: 'losing is normal, not an error');
      expect((await db.taskById('t1'))!.title, 'Task');
      expect(
        (r.changes.single as SyncChangeTask).row.title,
        'Task',
        reason: 'the server hands back the row that won',
      );
    },
  );

  test('a re-log for a loser does not grow the change log', () async {
    final ben = await user('ben');
    final first = await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    Future<int> logRows() async => (await db.select(db.syncLog).get()).length;
    final before = await logRows();

    for (var i = 0; i < 3; i++) {
      await push(ben, [
        SyncChange.task(task('t1', 'l1', deviceClock('old'), title: 'Stale')),
      ], cursor: first.cursor);
    }
    expect(await logRows(), before + 1, reason: 'one live row per (row, user)');

    // A real edit supersedes the per-user entry rather than adding to it.
    await push(ben, [
      SyncChange.task(task('t1', 'l1', laterClock('dev'), title: 'Newer')),
    ]);
    expect(await logRows(), before);
  });

  test('a stale push from a stranger is refused, not answered', () async {
    final ben = await user('ben');
    final anna = await user('anna');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    final stale = task('t1', 'l1', deviceClock('old'), title: 'Stale');
    final r = await push(anna, [SyncChange.task(stale)]);

    expect(r.rejected.single.reason, 'forbidden');
    expect(r.changes, isEmpty, reason: 'a loss must not leak the row');
  });

  test('an oversized push is refused before anything is written', () async {
    final ben = await user('ben');
    await push(ben, [SyncChange.list(list('l1', dev))]);
    sync = SyncService(
      db,
      now: () => fixedNow,
      clock: HlcClock(node: 'srv', now: () => fixedNow),
      maxChanges: 2,
    );

    final changes = [
      for (var i = 0; i < 3; i++) SyncChange.task(task('t$i', 'l1', dev)),
    ];
    await expectLater(
      () => sync.sync(ben, SyncRequest(cursor: 0, changes: changes)),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'too_many_changes'),
      ),
    );
    expect(
      await db.select(db.tasks).get(),
      isEmpty,
      reason: 'the cap has to be checked outside the write transaction',
    );
  });

  test('tombstones sync like any other row', () async {
    final ben = await user('ben');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);
    final stamp = dev.now().toString();
    final deleted = (await db.taskById('t1'))!
        .copyWith(updatedAt: stamp, deletedAt: stamp);
    final r = await push(ben, [SyncChange.task(deleted)], cursor: 2);
    expect((r.changes.single as SyncChangeTask).row.deletedAt, stamp);
  });

  test('a photo travels with the task it hangs off', () async {
    final ben = await user('ben');
    final anna = await user('anna');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.photo(photo('p1', 't1', dev)),
    ]);
    expect((await db.photoById('p1'))!.sha256, 'a' * 64);

    // Anna joins the list; the next push re-logs the photo for her too.
    await db
        .into(db.listMembers)
        .insert(
          ListMembersCompanion.insert(
            listId: 'l1',
            userId: anna,
            role: MemberRole.editor.name,
          ),
        );
    await push(ben, [SyncChange.photo(photo('p1', 't1', laterClock('dev')))]);

    final pulled = await push(anna, []);
    expect(pulled.changes.whereType<SyncChangePhoto>().single.row.id, 'p1');
  });

  test('a photo on a task you are not a member of is refused', () async {
    final ben = await user('ben');
    final mallory = await user('mallory');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);

    final refused = await push(mallory, [
      SyncChange.photo(photo('p1', 't1', dev)),
    ]);
    expect(refused.rejected.single.reason, 'forbidden');
    expect(await db.photoById('p1'), isNull);
  });

  test('a photo whose task is unknown is refused', () async {
    final ben = await user('ben');
    final refused = await push(ben, [
      SyncChange.photo(photo('p1', 'nope', dev)),
    ]);
    expect(refused.rejected.single.reason, 'unknown_task');
  });

  // Controller decision: a photo naming a hash that is not a bare 64-char
  // lowercase hex string is refused outright, before it can ever be read
  // back through GET /blobs/<hash> and resolved by BlobStore.fileFor into a
  // path outside the blob directory.
  test('a photo whose sha256 is not a valid hash is refused', () async {
    final ben = await user('ben');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);

    final refused = await push(ben, [
      SyncChange.photo(photo('p1', 't1', dev, sha: '../../../../etc/passwd')),
    ]);
    expect(refused.rejected.single.reason, 'invalid_row');
    expect(await db.photoById('p1'), isNull);

    // Checked before the task lookup: an unknown task must not mask it.
    final refusedUnknownTask = await push(ben, [
      SyncChange.photo(photo('p2', 'nope', dev, sha: '../../../../etc/passwd')),
    ]);
    expect(refusedUnknownTask.rejected.single.reason, 'invalid_row');
  });

  test('moving a task to another list carries its photos', () async {
    final ben = await user('ben');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.list(list('l2', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.photo(photo('p1', 't1', dev)),
    ]);

    await push(ben, [SyncChange.task(task('t1', 'l2', laterClock('dev')))]);

    final entries = await (db.select(
      db.syncLog,
    )..where((t) => t.entity.equals('photo'))).get();
    expect(
      entries.map((e) => '${e.op}:${e.listId}'),
      containsAll(['revoke:l1', 'upsert:l2']),
    );
  });
}
