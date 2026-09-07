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

  Future<SyncResponse> push(
    String userId,
    List<SyncChange> changes, {
    int cursor = 0,
  }) async => (await sync.sync(
    userId,
    SyncRequest(cursor: cursor, changes: changes),
  )).response;

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
      final r4 = await push(ben, [SyncChange.task(t)], cursor: r3.cursor);
      expect(r4.changes, isEmpty);
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
}
