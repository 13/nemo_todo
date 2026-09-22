import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() async {
    db = testDatabase();
    repository = NotesRepository(db, testClock('a'), sequentialIds('n'));
    // Most tests file notes under 'l1'; watchAll and search now join to
    // the list, so it has to actually exist and be live.
    await db.upsertList(
      TaskList(
        id: 'l1',
        name: 'List',
        sortKey: SortKey.first(),
        updatedAt: testClock('l').now().toString(),
      ),
    );
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

    expect(
      [for (final n in await repository.search('flour').first) n.title],
      ['Bread'],
    );
    expect(
      [for (final n in await repository.search('brea').first) n.title],
      ['Bread'],
    );
    expect(await repository.search('  ').first, isEmpty);
  });

  test('a deleted note is tombstoned, not removed', () async {
    final note = await repository.create(listId: 'l1', title: 'Bread');

    await repository.delete(note.id);

    expect(await repository.watchByList('l1').first, isEmpty);
    expect((await db.noteById(note.id))!.isDeleted, isTrue);
  });

  test('deleting a note stamps updatedAt with the tombstone itself', () async {
    final note = await repository.create(listId: 'l1', title: 'Bread');

    await repository.delete(note.id);

    final row = await db.noteById(note.id);
    expect(
      row!.updatedAt,
      row.deletedAt,
      reason: 'matches TasksRepository, which reuses the one stamp',
    );
  });

  test('a restored note is no longer tombstoned', () async {
    final note = await repository.create(listId: 'l1', title: 'Bread');
    await repository.delete(note.id);

    await repository.restore(note.id);

    expect((await db.noteById(note.id))!.isDeleted, isFalse);
    expect(
      [for (final n in await repository.watchByList('l1').first) n.title],
      ['Bread'],
    );
  });

  test('moving a note carries it to the other list', () async {
    final note = await repository.create(listId: 'l1', title: 'Bread');

    await repository.moveToList(note.id, 'l2');

    expect(await repository.watchByList('l1').first, isEmpty);
    expect(
      [for (final n in await repository.watchByList('l2').first) n.title],
      ['Bread'],
    );
  });

  test('watchAll does not surface a note whose list is deleted', () async {
    final live = TaskList(
      id: 'l1',
      name: 'Live',
      sortKey: SortKey.first(),
      updatedAt: testClock('l').now().toString(),
    );
    final gone = TaskList(
      id: 'l2',
      name: 'Gone',
      sortKey: SortKey.first(),
      updatedAt: testClock('l').now().toString(),
      deletedAt: testClock('l').now().toString(),
    );
    await db.upsertList(live);
    await db.upsertList(gone);
    await repository.create(listId: 'l1', title: 'Bread');
    await repository.create(listId: 'l2', title: 'Orphaned');

    final notes = await repository.watchAll().first;

    expect([for (final n in notes) n.title], ['Bread']);
  });

  test('search treats a literal % or _ as itself, not a wildcard', () async {
    await repository.create(listId: 'l1', title: '50% off');
    await repository.create(listId: 'l1', title: '50 something off');
    await repository.create(listId: 'l1', title: 'a_b');
    await repository.create(listId: 'l1', title: 'axb');

    expect(
      [for (final n in await repository.search('50%').first) n.title],
      ['50% off'],
    );
    expect(
      [for (final n in await repository.search('a_b').first) n.title],
      ['a_b'],
    );
  });

  test('search does not surface a note whose list is deleted', () async {
    final live = TaskList(
      id: 'l1',
      name: 'Live',
      sortKey: SortKey.first(),
      updatedAt: testClock('l').now().toString(),
    );
    final gone = TaskList(
      id: 'l2',
      name: 'Gone',
      sortKey: SortKey.first(),
      updatedAt: testClock('l').now().toString(),
      deletedAt: testClock('l').now().toString(),
    );
    await db.upsertList(live);
    await db.upsertList(gone);
    await repository.create(listId: 'l1', title: 'Bread and butter');
    await repository.create(listId: 'l2', title: 'Bread and jam');

    final notes = await repository.search('bread').first;

    expect([for (final n in notes) n.title], ['Bread and butter']);
  });
}
