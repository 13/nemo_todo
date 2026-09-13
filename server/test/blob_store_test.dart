import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late BlobStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('nemo-blobs');
    store = BlobStore(root.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('writes bytes to a path fanned out by their hash', () async {
    final bytes = [1, 2, 3, 4];
    final hash = sha256.convert(bytes).toString();
    expect(BlobStore.hashOf(bytes), hash);
    expect(await store.exists(hash), isFalse);

    await store.write(hash, bytes);

    expect(await store.exists(hash), isTrue);
    expect(
      store.fileFor(hash).path,
      '${root.path}/${hash.substring(0, 2)}/${hash.substring(2, 4)}/$hash',
    );
    expect(await store.read(hash).expand((c) => c).toList(), bytes);
  });

  test('writing the same hash twice leaves one file', () async {
    final bytes = [9, 9, 9];
    final hash = BlobStore.hashOf(bytes);
    await store.write(hash, bytes);
    await store.write(hash, bytes);
    expect(root.listSync(recursive: true).whereType<File>().length, 1);
  });

  test('writing the same hash concurrently is conflict-free', () async {
    // An interrupted upload can simply be repeated, and the same photo
    // sent by two people at once is stored once - neither write should
    // throw, and no temp file should be left behind fanned out with it.
    final bytes = [5, 5, 5, 5, 5];
    final hash = BlobStore.hashOf(bytes);
    for (var i = 0; i < 20; i++) {
      await Future.wait([store.write(hash, bytes), store.write(hash, bytes)]);
    }

    expect(await store.read(hash).expand((c) => c).toList(), bytes);
    final entries = root.listSync(recursive: true).whereType<File>().toList();
    expect(entries.length, 1, reason: 'no temp files should be left behind');
    expect(entries.single.path, store.fileFor(hash).path);
  });

  test('isValidHash accepts only a bare lowercase sha256 digest', () {
    expect(BlobStore.isValidHash('a' * 64), isTrue);
    expect(BlobStore.isValidHash(('a' * 64).toUpperCase()), isFalse);
    expect(BlobStore.isValidHash('a' * 63), isFalse);
    expect(BlobStore.isValidHash('${'a' * 64}/'), isFalse);
    expect(BlobStore.isValidHash('../../../../etc/passwd'), isFalse);
    expect(BlobStore.isValidHash('g' * 64), isFalse);
  });

  test('deleting removes the file and forgets it existed', () async {
    final bytes = [7];
    final hash = BlobStore.hashOf(bytes);
    await store.write(hash, bytes);
    await store.delete(hash);
    expect(await store.exists(hash), isFalse);
    // Deleting what is not there is not an error: a sweep may race a
    // delete that already happened.
    await store.delete(hash);
  });
}
