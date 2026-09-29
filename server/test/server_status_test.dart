import 'dart:io';

import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';

void main() {
  late ServerDatabase db;
  late Directory dir;
  late String dbPath;

  setUp(() {
    db = ServerDatabase.memory();
    dir = Directory.systemTemp.createTempSync('nemo-status');
    // The counts come from `db`; the size from whatever sits at the path.
    dbPath = '${dir.path}/nemo.db';
    File(dbPath).writeAsBytesSync(List.filled(4096, 0));
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<ServerStatus> status({DateTime? at}) =>
      ServerStatus.read(db, dbPath: dbPath, now: () => at ?? fixedNow);

  test('an empty server has nothing to count', () async {
    final s = await status();

    expect(s.databaseBytes, 4096);
    expect(s.accounts, 0);
    expect(s.lists, 0);
    expect(s.tasks, 0);
    expect(s.blobs, 0);
    expect(s.blobBytes, 0);
    expect(s.activeSessions, 0);
    expect(s.lastHousekeeping, isNull);
  });

  test('the write-ahead log counts towards the database size', () async {
    File('$dbPath-wal').writeAsBytesSync(List.filled(1000, 0));

    expect((await status()).databaseBytes, 5096);
  });

  test('counts accounts, live rows, blobs and sessions', () async {
    final auth = AuthService(
      db,
      allowSignup: true,
      bcryptRounds: 4,
      now: () => fixedNow,
    );
    final ben = (await auth.signup('ben', 'password123')).user.id;
    await auth.signup('ada', 'password123');
    await auth.login('ben', 'password123');

    final dev = deviceClock('dev');
    final later = laterClock('dev');
    final sync = SyncService(
      db,
      now: () => fixedNow,
      clock: HlcClock(node: 'srv', now: () => fixedNow),
    );
    await sync.sync(
      ben,
      SyncRequest(
        cursor: 0,
        changes: [
          SyncChange.list(list('l1', dev)),
          SyncChange.list(list('l2', dev)),
          SyncChange.task(task('t1', 'l1', dev)),
          SyncChange.task(task('t2', 'l1', dev)),
          SyncChange.task(task('t3', 'l1', dev)),
        ],
      ),
    );
    final gone = later.now().toString();
    await sync.sync(
      ben,
      SyncRequest(
        cursor: 0,
        changes: [
          SyncChange.list(
            list('l2', dev).copyWith(deletedAt: gone, updatedAt: gone),
          ),
          SyncChange.task(
            task('t3', 'l1', dev).copyWith(deletedAt: gone, updatedAt: gone),
          ),
        ],
      ),
    );

    for (final (hash, size) in [('a' * 64, 1000), ('b' * 64, 2500)]) {
      await db
          .into(db.blobs)
          .insert(
            BlobsCompanion.insert(
              sha256: hash,
              byteSize: size,
              ownerUserId: ben,
              createdAt: 0,
            ),
          );
    }

    final s = await status();
    expect(s.accounts, 2);
    expect(s.lists, 1);
    expect(s.deletedLists, 1);
    expect(s.tasks, 2);
    expect(s.deletedTasks, 1);
    expect(s.blobs, 2);
    expect(s.blobBytes, 3500);
    expect(s.activeSessions, 3);

    final muchLater = fixedNow.add(const Duration(days: 365));
    expect(
      (await status(at: muchLater)).activeSessions,
      0,
      reason: 'an expired session is not an active one',
    );
  });

  test('a purge records when housekeeping last ran', () async {
    final blobs = BlobStore('${dir.path}/blobs');
    await PurgeService(
      db,
      blobs: blobs,
      now: () => fixedNow,
    ).purge(dryRun: true);
    expect(
      (await status()).lastHousekeeping,
      isNull,
      reason: 'a dry run changes nothing, not even this',
    );

    await PurgeService(db, blobs: blobs, now: () => fixedNow).purge();
    expect((await status()).lastHousekeeping, fixedNow);
  });

  test('reads as a short report', () async {
    await db.setLastHousekeeping(fixedNow.subtract(const Duration(days: 3)));
    final text = (await status()).describe(dbPath: dbPath, now: fixedNow);

    expect(text, contains('database      $dbPath, 4.0 KB'));
    expect(text, contains('accounts      0'));
    expect(text, contains('lists         0 (0 deleted, awaiting purge)'));
    expect(text, contains('blobs         0, 0 B'));
    expect(text, contains('sessions      0 active'));
    expect(text, contains('housekeeping  last purge 3 day(s) ago'));
  });

  test('says when housekeeping has never run', () async {
    final text = (await status()).describe(dbPath: dbPath, now: fixedNow);
    expect(text, contains('housekeeping  never -- see `nemo_server purge`'));
  });

  test('sizes read in the unit that suits them', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1023), '1023 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
  });
}
