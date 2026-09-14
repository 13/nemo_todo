import 'dart:convert';

import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  test('SyncRequest round trip with union changes', () {
    const req = SyncRequest(
      cursor: 7,
      changes: [
        SyncChange.task(
          Task(
            id: 't',
            listId: 'l',
            title: 'x',
            sortKey: 'V',
            updatedAt: '0000000000001-0000-n',
          ),
        ),
        SyncChange.revoke(target: SyncEntity.list, id: 'l'),
      ],
    );
    final json = jsonDecode(jsonEncode(req.toJson())) as Map<String, dynamic>;
    final changes = json['changes'] as List<dynamic>;
    expect(changes.first, containsPair('type', 'task'));
    expect(changes.last, {'type': 'revoke', 'target': 'list', 'id': 'l'});
    expect(SyncRequest.fromJson(json), req);
  });

  test('SyncChange exposes entity and rowId for every case', () {
    const list = TaskList(
      id: 'l',
      name: 'n',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    const sub = Subtask(
      id: 's',
      taskId: 't',
      title: 'x',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    expect(const SyncChange.list(list).entity, SyncEntity.list);
    expect(const SyncChange.list(list).rowId, 'l');
    expect(const SyncChange.subtask(sub).entity, SyncEntity.subtask);
    expect(const SyncChange.subtask(sub).rowId, 's');
    const revoke = SyncChange.revoke(target: SyncEntity.task, id: 't');
    expect(revoke.entity, SyncEntity.task);
    expect(revoke.rowId, 't');
  });

  test('SyncResponse round trip', () {
    const res = SyncResponse(
      cursor: 9,
      hasMore: true,
      serverHlc: '0000000000009-0000-srv',
      serverVersion: '0.4.0',
      rejected: [
        RejectedChange(
          entity: SyncEntity.task,
          rowId: 't',
          reason: 'forbidden',
        ),
      ],
      members: {
        'l': [ListMember(username: 'ben', role: MemberRole.owner)],
      },
    );
    final json = jsonDecode(jsonEncode(res.toJson())) as Map<String, dynamic>;
    expect(SyncResponse.fromJson(json), res);
    expect((json['members'] as Map<String, dynamic>)['l'], [
      {'username': 'ben', 'role': 'owner'},
    ]);
    expect(json['has_more'], isTrue);
    expect(json['server_hlc'], '0000000000009-0000-srv');
    expect(json['server_version'], '0.4.0');
  });

  test('a server too old to name itself decodes rather than throws', () {
    // The field was added after 0.4.0. A server without it must still be
    // something this app can talk to, and "did not say" has to be
    // distinguishable from a version -- it is not a mismatch.
    final json = {'cursor': 3, 'server_hlc': '0000000000003-0000-srv'};
    final res = SyncResponse.fromJson(json);
    expect(res.serverVersion, isEmpty);
    expect(res.cursor, 3);
  });

  test('a photo change survives a round trip through JSON', () {
    const photo = Photo(
      id: 'p1',
      taskId: 't1',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      byteSize: 4096,
      width: 2048,
      height: 1536,
      sortKey: 'V',
      updatedAt: '2026-09-13T10:00:00.000Z-0000-node',
    );
    const change = SyncChange.photo(photo);
    final json = change.toJson();
    expect(json['type'], 'photo');
    final back = SyncChange.fromJson(json);
    expect(back, change);
    expect(back.entity, SyncEntity.photo);
    expect(back.rowId, 'p1');
    expect(photo.isDeleted, isFalse);
    expect(photo.copyWith(deletedAt: photo.updatedAt).isDeleted, isTrue);
  });

  test('a photo merges by its stamp like any other row', () {
    const older = Photo(
      id: 'p1',
      taskId: 't1',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      byteSize: 10,
      width: 1,
      height: 1,
      sortKey: 'V',
      updatedAt: '2026-09-13T10:00:00.000Z-0000-a',
    );
    final newer = older.copyWith(updatedAt: '2026-09-13T10:00:01.000Z-0000-a');
    expect(incomingWins(older, newer), isTrue);
    expect(incomingWins(newer, older), isFalse);
  });
}
