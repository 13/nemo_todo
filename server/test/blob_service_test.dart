import 'dart:io';

import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';

/// A [BlobStore] that runs [beforeFirstExists] the first time an upload
/// asks whether a file is on disk, standing in for a sweep that lands in
/// the middle of that upload.
class _InterruptedBlobStore extends BlobStore {
  _InterruptedBlobStore(super.root, this.beforeFirstExists);

  final Future<void> Function() beforeFirstExists;
  var _interrupted = false;

  @override
  Future<bool> exists(String sha256) async {
    if (!_interrupted) {
      _interrupted = true;
      await beforeFirstExists();
    }
    return await super.exists(sha256);
  }
}

void main() {
  late ServerDatabase db;
  late Directory root;
  late DateTime now;
  final bytes = [1, 2, 3, 4];
  final hash = BlobStore.hashOf(bytes);
  final stale = PurgeService.defaultRetention + const Duration(days: 1);

  setUp(() {
    db = ServerDatabase.memory();
    root = Directory.systemTemp.createTempSync('nemo-blob-service');
    now = fixedNow;
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<String> user(String name) async {
    final auth = AuthService(db, allowSignup: true, bcryptRounds: 4);
    return (await auth.signup(name, 'password123')).user.id;
  }

  BlobService service(BlobStore store) => BlobService(
    db,
    store,
    maxBlobBytes: 1024,
    accountQuotaBytes: 1024,
    now: () => now,
  );

  Future<BlobRow?> row() => (db.select(
    db.blobs,
  )..where((t) => t.sha256.equals(hash))).getSingleOrNull();

  Future<void> seedStale(BlobStore store, String owner) async {
    await store.write(hash, bytes);
    await db
        .into(db.blobs)
        .insert(
          BlobsCompanion.insert(
            sha256: hash,
            byteSize: bytes.length,
            ownerUserId: owner,
            createdAt: now.subtract(stale).millisecondsSinceEpoch,
          ),
        );
  }

  test('re-uploading a stale blob makes it young again, so the purge that '
      'follows leaves it for the row about to name it', () async {
    final store = BlobStore(root.path);
    final ben = await user('ben');
    final mallory = await user('mallory');
    await seedStale(store, ben);
    final modified = store.fileFor(hash).lastModifiedSync();

    await service(store).put(mallory, hash, bytes);

    final held = await row();
    expect(held!.createdAt, now.millisecondsSinceEpoch);
    expect(held.ownerUserId, ben);
    expect(
      await db.bytesOwnedBy(mallory),
      0,
      reason: 'bytes already held cost the uploader nothing',
    );
    expect(store.fileFor(hash).lastModifiedSync(), modified);

    final report = await PurgeService(db, blobs: store, now: () => now).purge();
    expect(report.blobs, 0);
    expect(await store.exists(hash), isTrue);
    expect(await row(), isNotNull);
  });

  test('uploading bytes a sweep already took stores them afresh', () async {
    final store = BlobStore(root.path);
    final ben = await user('ben');
    final mallory = await user('mallory');
    await seedStale(store, ben);
    expect(
      (await PurgeService(db, blobs: store, now: () => now).purge()).blobs,
      1,
    );

    await service(store).put(mallory, hash, bytes);

    expect(await store.exists(hash), isTrue);
    final fresh = await row();
    expect(fresh!.createdAt, now.millisecondsSinceEpoch);
    expect(fresh.ownerUserId, mallory);
    expect(await db.bytesOwnedBy(mallory), bytes.length);
  });

  test('a sweep landing in the middle of an upload leaves the bytes and a '
      'row naming them', () async {
    final ben = await user('ben');
    late BlobStore store;
    store = _InterruptedBlobStore(root.path, () async {
      await PurgeService(db, blobs: store, now: () => now).purge();
    });
    await seedStale(store, ben);

    await service(store).put(ben, hash, bytes);

    expect(await store.exists(hash), isTrue);
    final held = await row();
    expect(held, isNotNull, reason: 'bytes no row names would be swept');
    expect(held!.createdAt, now.millisecondsSinceEpoch);
    expect(await db.bytesOwnedBy(ben), bytes.length);
  });
}
