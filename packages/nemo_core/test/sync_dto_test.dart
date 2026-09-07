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
  });
}
