import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = testDatabase();
    repository = NotesRepository(db, testClock('a'), sequentialIds('n'));
  });
  tearDown(() => db.close());

  test('a new note lands in its list, pinned notes first', () async {
    await repository.create(listId: 'l1', title: 'Bread');
    final pinned = await repository.create(listId: 'l1', title: 'Milk');
    await repository.setPinned(pinned.id, pinned: true);

    final notes = await repository.watchByList('l1').first;

    expect([for (final n in notes) n.title], ['Milk', 'Bread']);
  });

  test('search matches the title and the body', () async {
    await repository.create(listId: 'l1', title: 'Bread', body: '500 g flour');
    await repository.create(listId: 'l1', title: 'Milk');

    expect([for (final n in await repository.search('flour').first) n.title], [
      'Bread',
    ]);
    expect([for (final n in await repository.search('brea').first) n.title], [
      'Bread',
    ]);
    expect(await repository.search('  ').first, isEmpty);
  });

  test('a deleted note is tombstoned, not removed', () async {
    final note = await repository.create(listId: 'l1', title: 'Bread');

    await repository.delete(note.id);

    expect(await repository.watchByList('l1').first, isEmpty);
    expect((await db.noteById(note.id))!.isDeleted, isTrue);
  });

  test('moving a note carries it to the other list', () async {
    final note = await repository.create(listId: 'l1', title: 'Bread');

    await repository.moveToList(note.id, 'l2');

    expect(await repository.watchByList('l1').first, isEmpty);
    expect([for (final n in await repository.watchByList('l2').first) n.title], [
      'Bread',
    ]);
  });
}
