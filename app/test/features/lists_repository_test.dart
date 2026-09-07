import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';

import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late ListsRepository repo;

  setUp(() {
    db = testDatabase();
    repo = ListsRepository(db, testClock(), sequentialIds('l'));
  });
  tearDown(() => db.close());

  test('ensureInbox creates one inbox and keeps it first', () async {
    final inbox = await repo.ensureInbox();
    expect(inbox.isInbox, isTrue);
    expect((await repo.ensureInbox()).id, inbox.id);
    await repo.create(name: ' Groceries ', color: 3);
    await repo.create(name: 'Work');
    final all = await repo.watchAll().first;
    expect(all.map((l) => l.name), ['Inbox', 'Groceries', 'Work']);
    expect(all[1].color, 3);
    expect(all[1].sortKey.compareTo(all[2].sortKey), lessThan(0));
  });

  test(
    'delete tombstones (never the inbox) and restore brings it back',
    () async {
      final inbox = await repo.ensureInbox();
      final work = await repo.create(name: 'Work');
      await repo.delete(inbox.id);
      await repo.delete(work.id);
      expect((await repo.watchAll().first).map((l) => l.id), [inbox.id]);
      expect((await db.listById(work.id))!.isDeleted, isTrue);
      await repo.restore(work.id);
      expect((await repo.watch(work.id).first)?.name, 'Work');
      expect(await db.outboxCount(), 2);
    },
  );

  test('save stamps a newer HLC', () async {
    final work = await repo.create(name: 'Work');
    await repo.save(work.copyWith(name: 'Job'));
    final saved = await db.listById(work.id);
    expect(saved!.name, 'Job');
    expect(saved.updatedAt.compareTo(work.updatedAt), greaterThan(0));
  });
}
