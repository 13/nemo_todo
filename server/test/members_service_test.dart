import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';

void main() {
  late ServerDatabase db;
  late SyncService sync;
  late MembersService members;
  late HlcClock dev;
  late String ben;
  late String anna;

  Future<SyncResponse> push(
    String userId,
    List<SyncChange> changes, {
    int cursor = 0,
  }) async => (await sync.sync(
    userId,
    SyncRequest(cursor: cursor, changes: changes),
  )).response;

  setUp(() async {
    db = ServerDatabase.memory();
    sync = SyncService(db, now: () => fixedNow);
    members = MembersService(db);
    dev = deviceClock('dev');
    final auth = AuthService(db, allowSignup: true, bcryptRounds: 4);
    ben = (await auth.signup('ben', 'password123')).user.id;
    anna = (await auth.signup('anna', 'password123')).user.id;
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.subtask(subtask('s1', 't1', dev)),
    ]);
  });
  tearDown(() => db.close());

  test(
    'share re-logs the list so the new member receives everything',
    () async {
      final before = await push(anna, []);
      expect(before.changes, isEmpty);
      final notify = await members.share(ben, 'l1', 'Anna', MemberRole.editor);
      expect(notify, {ben, anna});
      final fromCursor = await push(anna, [], cursor: before.cursor);
      expect(fromCursor.changes.map((c) => c.rowId), ['l1', 't1', 's1']);
      expect(
        fromCursor.members['l1']!.map((m) => '${m.username}:${m.role.name}'),
        ['ben:owner', 'anna:editor'],
      );
      final fromZero = await push(anna, []);
      expect(fromZero.changes.map((c) => c.rowId), ['l1', 't1', 's1']);
      expect(await members.members(anna, 'l1'), hasLength(2));
    },
  );

  test('unshare revokes for that member only', () async {
    await members.share(ben, 'l1', 'anna', MemberRole.editor);
    final annaSynced = await push(anna, []);
    final benSynced = await push(ben, []);
    final notify = await members.unshare(ben, 'l1', 'anna');
    expect(notify, {ben, anna});

    final annaAfter = await push(anna, [], cursor: annaSynced.cursor);
    expect(annaAfter.changes.every((c) => c is SyncChangeRevoke), isTrue);
    expect(annaAfter.changes.map((c) => c.rowId), ['l1', 't1', 's1']);
    expect(annaAfter.members, isEmpty);

    final benAfter = await push(ben, [], cursor: benSynced.cursor);
    expect(
      benAfter.changes,
      isEmpty,
      reason: 'remaining members are unaffected',
    );

    final rejected = await push(anna, [
      SyncChange.task(task('t2', 'l1', deviceClock('anna'))),
    ]);
    expect(rejected.rejected.single.reason, 'forbidden');
    expect(
      () => members.members(anna, 'l1'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
  });

  test('only owners share, owners cannot be removed or demoted', () async {
    await members.share(ben, 'l1', 'anna', MemberRole.editor);
    expect(
      () => members.share(anna, 'l1', 'ben', MemberRole.editor),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_owner')),
    );
    expect(
      () => members.share(ben, 'l1', 'ben', MemberRole.editor),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'cannot_change_owner',
        ),
      ),
    );
    expect(
      () => members.share(ben, 'l1', 'anna', MemberRole.owner),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'cannot_change_owner',
        ),
      ),
    );
    expect(
      () => members.unshare(ben, 'l1', 'ben'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'cannot_remove_owner',
        ),
      ),
    );
    expect(
      () => members.share(ben, 'l1', 'nobody', MemberRole.editor),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'unknown_user'),
      ),
    );
    expect(
      () => members.share(ben, 'zzz', 'anna', MemberRole.editor),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'unknown_list'),
      ),
    );
    expect(
      () => members.unshare(ben, 'l1', 'nobody'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'unknown_user'),
      ),
    );
  });

  group('ownership transfer', () {
    test('swaps the roles, the row and what each side may do', () async {
      await members.share(ben, 'l1', 'anna', MemberRole.editor);
      final synced = await push(anna, []);

      final notify = await members.transferOwnership(ben, 'l1', 'Anna');
      expect(notify, {ben, anna});

      final seen = await push(anna, [], cursor: synced.cursor);
      expect(seen.members['l1']!.map((m) => '${m.username}:${m.role.name}'), [
        'anna:owner',
        'ben:editor',
      ]);
      // The row carries the owner, and the app reads it to decide who may
      // touch sharing, so it has to travel with the change.
      final row = seen.changes.whereType<SyncChangeList>().single.row;
      expect(row.ownerId, anna);

      // And the powers move with it.
      await members.share(anna, 'l1', 'ben', MemberRole.editor);
      expect(
        () => members.unshare(ben, 'l1', 'anna'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_owner')),
      );
    });

    test('only the owner may hand it on, and only to a member', () async {
      expect(
        () => members.transferOwnership(ben, 'l1', 'anna'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'not_member'),
        ),
      );
      await members.share(ben, 'l1', 'anna', MemberRole.editor);
      expect(
        () => members.transferOwnership(anna, 'l1', 'ben'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_owner')),
      );
      expect(
        () => members.transferOwnership(ben, 'l1', 'ben'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'already_owner'),
        ),
      );
      expect(
        () => members.transferOwnership(ben, 'l1', 'nobody'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'unknown_user'),
        ),
      );
    });

    test('a handed-over list stays where its tasks are', () async {
      await members.share(ben, 'l1', 'anna', MemberRole.editor);
      await members.transferOwnership(ben, 'l1', 'anna');
      // Both sides still get the whole list. The order differs from a
      // plain share: the transfer re-logs the list, so it arrives after the
      // rows that were logged before it.
      final ownerView = await push(anna, []);
      expect(
        ownerView.changes.map((c) => c.rowId),
        containsAll(['l1', 't1', 's1']),
      );
      final formerView = await push(ben, []);
      expect(
        formerView.changes.map((c) => c.rowId),
        containsAll(['l1', 't1', 's1']),
      );
    });
  });

  test('re-sharing after unshare delivers rows again in order', () async {
    await members.share(ben, 'l1', 'anna', MemberRole.editor);
    final synced = await push(anna, []);
    await members.unshare(ben, 'l1', 'anna');
    await members.share(ben, 'l1', 'anna', MemberRole.editor);
    final r = await push(anna, [], cursor: synced.cursor);
    final kinds = r.changes
        .map((c) => '${c is SyncChangeRevoke ? 'revoke' : 'upsert'}:${c.rowId}')
        .toList();
    expect(kinds, [
      'revoke:l1',
      'revoke:t1',
      'revoke:s1',
      'upsert:l1',
      'upsert:t1',
      'upsert:s1',
    ]);
  });
}
