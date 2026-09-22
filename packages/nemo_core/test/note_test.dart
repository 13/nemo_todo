import 'dart:convert';

import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  test('Note JSON round trip keeps the body and the defaults', () {
    const note = Note(
      id: 'n1',
      listId: 'l1',
      title: 'Bread',
      body: '# Bread\n\n500 g flour',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );

    final json = jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>;

    expect(json['list_id'], 'l1');
    expect(json['body'], '# Bread\n\n500 g flour');
    expect(json['pinned'], false);
    expect(json['deleted_at'], isNull);
    expect(Note.fromJson(json), note);
    expect(note.isDeleted, isFalse);
  });

  test('a tombstoned note says so', () {
    const note = Note(
      id: 'n1',
      listId: 'l1',
      title: 'Bread',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
      deletedAt: '0000000000002-0000-n',
    );

    expect(note.isDeleted, isTrue);
    expect(note.body, '');
  });
}
