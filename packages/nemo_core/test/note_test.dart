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

  test('a task photo travels as the JSON it always did', () {
    // Not const: String's `*` operator is not foldable at compile time.
    final photo = Photo(
      id: 'p1',
      parentId: 't1',
      sha256: 'a' * 64,
      byteSize: 10,
      width: 2,
      height: 1,
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );

    final json = jsonDecode(jsonEncode(photo.toJson())) as Map<String, dynamic>;

    expect(json['task_id'], 't1');
    expect(json['parent_kind'], 'task');
    expect(Photo.fromJson(json), photo);
  });

  test('a photo from before notes reads as a task photo', () {
    final json = {
      'id': 'p1',
      'task_id': 't1',
      'sha256': 'a' * 64,
      'byte_size': 10,
      'width': 2,
      'height': 1,
      'sort_key': 'V',
      'updated_at': '0000000000001-0000-n',
    };

    final photo = Photo.fromJson(json);

    expect(photo.parentKind, PhotoParent.task);
    expect(photo.parentId, 't1');
  });

  test('a note photo carries its kind', () {
    // Not const: String's `*` operator is not foldable at compile time.
    final photo = Photo(
      id: 'p2',
      parentKind: PhotoParent.note,
      parentId: 'n1',
      sha256: 'b' * 64,
      byteSize: 10,
      width: 2,
      height: 1,
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );

    final json = jsonDecode(jsonEncode(photo.toJson())) as Map<String, dynamic>;

    expect(json['parent_kind'], 'note');
    expect(json['task_id'], 'n1');
    expect(Photo.fromJson(json), photo);
  });
}
