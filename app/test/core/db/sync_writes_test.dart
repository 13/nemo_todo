import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late HlcClock clock;

  TaskList list(String id) => TaskList(
    id: id,
    name: 'L',
    sortKey: 'V',
    updatedAt: clock.now().toString(),
  );
  Task task(String id, String listId) => Task(
    id: id,
    listId: listId,
    title: 'T',
    sortKey: 'V',
    updatedAt: clock.now().toString(),
  );

  setUp(() {
    db = testDatabase();
    clock = testClock();
  });
  tearDown(() => db.close());

  test('local upsert writes the row, one outbox entry and hlcLast', () async {
    final l = list('l1');
    await db.upsertList(l);
    await db.upsertList(
      l.copyWith(name: 'renamed', updatedAt: clock.now().toString()),
    );
    expect((await db.listById('l1'))!.name, 'renamed');
    expect(await db.outboxCount(), 1);
    final changes = await db.outboxChanges();
    expect((changes.single as SyncChangeList).row.name, 'renamed');
    expect(
      await KvStore(db).get(KvKeys.hlcLast),
      (await db.listById('l1'))!.updatedAt,
    );
  });

  test(
    'applyRemote keeps a newer local row and takes a newer remote one',
    () async {
      final local = task('t1', 'l1').copyWith(title: 'local');
      await db.upsertTask(local);
      final older = local.copyWith(
        title: 'remote-old',
        updatedAt: '0000000000001-0000-srv',
      );
      expect(await db.applyRemote(SyncChange.task(older)), isNull);
      expect((await db.taskById('t1'))!.title, 'local');
      expect(
        await db.outboxCount(),
        1,
        reason: 'my newer edit still has to reach the server',
      );
      final newer = local.copyWith(
        title: 'remote-new',
        updatedAt: clock.now().toString(),
      );
      expect(await db.applyRemote(SyncChange.task(newer)), newer);
      expect((await db.taskById('t1'))!.title, 'remote-new');
      expect(
        await db.outboxCount(),
        0,
        reason: 'the queued edit lost, so it must not be pushed again',
      );
    },
  );

  test(
    'revoking a list removes its tasks, subtasks and queued changes',
    () async {
      await db.upsertList(list('l1'));
      await db.upsertTask(task('t1', 'l1'));
      await db.upsertSubtask(
        Subtask(
          id: 's1',
          taskId: 't1',
          title: 'S',
          sortKey: 'V',
          updatedAt: clock.now().toString(),
        ),
      );
      await db.applyRemote(
        const SyncChange.revoke(target: SyncEntity.list, id: 'l1'),
      );
      expect(await db.listById('l1'), isNull);
      expect(await db.taskById('t1'), isNull);
      expect(await db.subtaskById('s1'), isNull);
      expect(await db.outboxCount(), 0);
    },
  );

  test('ackOutbox skips rows edited after the push', () async {
    final t = task('t1', 'l1');
    await db.upsertTask(t);
    final pushed = await db.outboxChanges();
    await db.upsertTask(
      t.copyWith(title: 'edited', updatedAt: clock.now().toString()),
    );
    await db.ackOutbox(pushed);
    expect(
      await db.outboxCount(),
      1,
      reason: 'the later edit must still be pushed',
    );
    await db.ackOutbox(await db.outboxChanges());
    expect(await db.outboxCount(), 0);
  });

  test('a remote row that wins clears the superseded outbox entry', () async {
    final t = task('t1', 'l1');
    await db.upsertTask(t);
    expect(await db.outboxCount(), 1);

    await db.applyRemote(
      SyncChange.task(
        t.copyWith(title: 'from the server', updatedAt: clock.now().toString()),
      ),
    );
    expect((await db.taskById('t1'))!.title, 'from the server');
    expect(
      await db.outboxCount(),
      0,
      reason: 'the queued edit lost, so there is nothing left to push',
    );
  });

  test('a remote row that loses leaves the pending edit queued', () async {
    final stale = task('t2', 'l1');
    final mine = stale.copyWith(
      title: 'mine',
      updatedAt: clock.now().toString(),
    );
    await db.upsertTask(mine);
    await db.applyRemote(SyncChange.task(stale));
    expect((await db.taskById('t2'))!.title, 'mine');
    expect(
      await db.outboxCount(),
      1,
      reason: 'my newer edit still has to reach the server',
    );
  });

  test('enqueueAll queues every row and outboxChanges drops orphans', () async {
    await db.upsertList(list('l1'));
    await db.upsertTask(task('t1', 'l1'));
    await db.clearOutbox();
    await db.enqueueAll();
    expect(await db.outboxCount(), 2);
    await db.dropOutbox(SyncEntity.task, 't1');
    expect((await db.outboxChanges()).map((c) => c.rowId), ['l1']);
  });

  test(
    'setListMeta records my role and members and clears stale rows',
    () async {
      await db.setListMeta({
        'l1': const [
          ListMember(username: 'ben', role: MemberRole.owner),
          ListMember(username: 'anna', role: MemberRole.editor),
        ],
        'l2': const [
          ListMember(username: 'anna', role: MemberRole.owner),
          ListMember(username: 'ben', role: MemberRole.editor),
        ],
      }, 'ben');
      final meta = await db.watchListMeta().first;
      expect(meta['l1']!.myRole, MemberRole.owner);
      expect(meta['l2']!.myRole, MemberRole.editor);
      expect(meta['l1']!.isOwner, isTrue);
      expect(meta['l2']!.isOwner, isFalse);
      expect(meta['l1']!.isShared, isTrue);
      expect(meta['l1']!.members.map((m) => m.username), ['ben', 'anna']);
      await db.setListMeta({
        'l1': const [ListMember(username: 'ben', role: MemberRole.owner)],
      }, 'ben');
      expect((await db.watchListMeta().first).keys, ['l1']);
      expect(await db.watchOutboxCount().first, 0);
    },
  );

  test(
    'a photo waits in the outbox until its bytes have been uploaded',
    () async {
      final clock = testClock('a');
      const hash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      await db.upsertTask(
        Task(
          id: 't1',
          listId: 'l1',
          title: 'T',
          sortKey: 'V',
          updatedAt: clock.now().toString(),
        ),
      );
      await db.rememberBlob(hash, byteSize: 12, state: 'pendingUpload');
      await db.upsertPhoto(
        Photo(
          id: 'p1',
          taskId: 't1',
          sha256: hash,
          byteSize: 12,
          width: 4,
          height: 3,
          sortKey: 'V',
          updatedAt: clock.now().toString(),
        ),
      );

      expect(
        (await db.outboxChanges()).whereType<SyncChangePhoto>(),
        isEmpty,
        reason: 'the server would hold a row whose bytes it cannot serve',
      );
      expect((await db.pendingBlobs()).single.sha256, hash);

      await db.markBlobSynced(hash);
      expect(
        (await db.outboxChanges()).whereType<SyncChangePhoto>().single.row.id,
        'p1',
      );
    },
  );

  test(
    'a pulled photo is applied, and revoking its task takes it away',
    () async {
      final clock = testClock('server');
      const hash =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      await db.applyRemote(
        SyncChange.task(
          Task(
            id: 't1',
            listId: 'l1',
            title: 'T',
            sortKey: 'V',
            updatedAt: clock.now().toString(),
          ),
        ),
      );
      await db.applyRemote(
        SyncChange.photo(
          Photo(
            id: 'p1',
            taskId: 't1',
            sha256: hash,
            byteSize: 9,
            width: 2,
            height: 2,
            sortKey: 'V',
            updatedAt: clock.now().toString(),
          ),
        ),
      );
      expect(await db.photoById('p1'), isNotNull);
      expect(await db.missingBlobHashes(), [hash]);

      await db.applyRemote(
        const SyncChange.revoke(target: SyncEntity.task, id: 't1'),
      );
      expect(await db.photoById('p1'), isNull);
      expect(await db.missingBlobHashes(), isEmpty);
    },
  );

  test('missing bytes are listed newest photo first', () async {
    const older =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const newer =
        '2222222222222222222222222222222222222222222222222222222222222222';
    await db.applyRemote(
      const SyncChange.task(
        Task(
          id: 't1',
          listId: 'l1',
          title: 'T',
          sortKey: 'V',
          updatedAt: '0000000000001-0000-srv',
        ),
      ),
    );
    Photo photo(String id, String sha256, String stamp) => Photo(
      id: id,
      taskId: 't1',
      sha256: sha256,
      byteSize: 9,
      width: 2,
      height: 2,
      sortKey: 'V',
      updatedAt: stamp,
    );
    // Applied oldest first, so the answer cannot just be insertion order.
    await db.applyRemote(
      SyncChange.photo(photo('p1', older, '0000000000002-0000-srv')),
    );
    await db.applyRemote(
      SyncChange.photo(photo('p2', newer, '0000000000003-0000-srv')),
    );

    expect(await db.missingBlobHashes(), [newer, older]);
  });
}
