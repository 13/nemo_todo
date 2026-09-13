import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/photos/data/photo_store_io.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';

// 64 lowercase hex characters: what a SHA-256 hex digest always looks
// like. `String` has no `*` operator, so these are spelled out in full
// rather than built from a repeat.
const hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const hashC =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
// Derived rather than hand-typed, so its length can't drift from hashA's
// verified 64 characters the way a fresh literal could.
final String hashD = hashA.replaceAll('a', 'd');

void main() {
  test('a file store keeps bytes across instances', () async {
    final dir = Directory.systemTemp.createTempSync('nemo-photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bytes = Uint8List.fromList([1, 2, 3]);

    await FilePhotoStore(dir.path).put(hashA, bytes);
    expect(await FilePhotoStore(dir.path).get(hashA), bytes);

    await FilePhotoStore(dir.path).remove(hashA);
    expect(await FilePhotoStore(dir.path).get(hashA), isNull);
    // Removing what is not there is not an error: two deletes can race.
    await FilePhotoStore(dir.path).remove(hashA);
  });

  test('a memory store forgets the least recently used', () async {
    final store = MemoryPhotoStore(maxEntries: 2);
    await store.put(hashA, Uint8List.fromList([1]));
    await store.put(hashB, Uint8List.fromList([2]));
    // Touching 'a' makes 'b' the oldest.
    await store.get(hashA);
    await store.put(hashC, Uint8List.fromList([3]));

    expect(await store.get(hashB), isNull);
    expect(await store.get(hashA), isNotNull);
    expect(await store.get(hashC), isNotNull);
  });

  test('a file store rejects a hash shaped like a path traversal', () async {
    final dir = Directory.systemTemp.createTempSync('nemo-photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FilePhotoStore(dir.path);
    final bytes = Uint8List.fromList([1, 2, 3]);

    expect(() => store.put('../escape', bytes), throwsArgumentError);
    expect(await store.get('../escape'), isNull);
    // A no-op, not a throw: nothing was there to remove.
    await store.remove('../escape');

    // Nothing was created inside the store's directory, and nothing
    // outside it either -- the traversal segment would have landed one
    // level above `dir`.
    expect(dir.listSync(), isEmpty);
    expect(File('${dir.path}/../escape.jpg').existsSync(), isFalse);
  });

  test('a file store rejects an uppercase hex hash', () async {
    final dir = Directory.systemTemp.createTempSync('nemo-photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FilePhotoStore(dir.path);
    final bytes = Uint8List.fromList([1, 2, 3]);
    final upper = hashA.toUpperCase();

    expect(() => store.put(upper, bytes), throwsArgumentError);
    expect(await store.get(upper), isNull);
    await store.remove(upper);

    expect(dir.listSync(), isEmpty);
  });

  test('a pinned entry survives eviction', () async {
    final store = MemoryPhotoStore(maxEntries: 2);
    await store.put(hashA, Uint8List.fromList([1]));
    await store.pin(hashA);
    await store.put(hashB, Uint8List.fromList([2]));
    await store.put(hashC, Uint8List.fromList([3]));
    await store.put(hashD, Uint8List.fromList([4]));

    // a survives even though it's the oldest entry, because it's pinned.
    expect(await store.get(hashA), isNotNull);
    // b was the least-recently-used *unpinned* entry once the count grew
    // past maxEntries, so it -- not a -- was evicted to make room.
    expect(await store.get(hashB), isNull);
    // c and d were never the least-recently-used unpinned entry, so
    // neither had to be evicted to bring the store back within bound.
    expect(await store.get(hashC), isNotNull);
    expect(await store.get(hashD), isNotNull);
  });

  test('pinning a hash before it is put still protects it', () async {
    final store = MemoryPhotoStore(maxEntries: 2);
    await store.pin(hashA);
    await store.put(hashA, Uint8List.fromList([1]));
    await store.put(hashB, Uint8List.fromList([2]));
    await store.put(hashC, Uint8List.fromList([3]));
    await store.put(hashD, Uint8List.fromList([4]));

    // The pin recorded before a existed still protects it once it's put.
    expect(await store.get(hashA), isNotNull);
  });

  test('unpinning re-enables eviction down to the bound', () async {
    final store = MemoryPhotoStore(maxEntries: 2);
    await store.pin(hashA);
    await store.put(hashA, Uint8List.fromList([1]));
    await store.put(hashB, Uint8List.fromList([2]));
    await store.put(hashC, Uint8List.fromList([3]));

    // Over maxEntries: 2, but nothing was evicted -- a's pin exempts it
    // from the bound, and b and c together don't exceed it.
    expect(await store.get(hashA), isNotNull);
    expect(await store.get(hashB), isNotNull);
    expect(await store.get(hashC), isNotNull);

    // Unpinning puts a back in the running, over the bound by one, so
    // eviction runs again and drops the least-recently-used entry: a
    // itself, untouched since its initial put.
    await store.unpin(hashA);
    expect(await store.get(hashA), isNull);
    expect(await store.get(hashB), isNotNull);
    expect(await store.get(hashC), isNotNull);
  });

  test('every entry may be pinned at once, even over maxEntries', () async {
    final store = MemoryPhotoStore(maxEntries: 1);
    await store.pin(hashA);
    await store.put(hashA, Uint8List.fromList([1]));
    await store.pin(hashB);
    await store.put(hashB, Uint8List.fromList([2]));

    // Both kept, no exception, even though the store now holds twice
    // what maxEntries allows -- there was nothing unpinned to evict.
    expect(await store.get(hashA), isNotNull);
    expect(await store.get(hashB), isNotNull);
  });

  test('removing an entry clears its pin', () async {
    final store = MemoryPhotoStore(maxEntries: 2);
    await store.pin(hashA);
    await store.put(hashA, Uint8List.fromList([1]));
    await store.remove(hashA);

    // Put again, unpinned this time -- if the earlier pin had survived
    // the remove, this entry would be protected from eviction below.
    await store.put(hashA, Uint8List.fromList([1]));
    await store.put(hashB, Uint8List.fromList([2]));
    await store.put(hashC, Uint8List.fromList([3]));

    expect(await store.get(hashA), isNull);
  });

  test('pin and unpin do nothing to a file store', () async {
    final dir = Directory.systemTemp.createTempSync('nemo-photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FilePhotoStore(dir.path);
    final bytes = Uint8List.fromList([1, 2, 3]);
    await store.put(hashA, bytes);

    await store.pin(hashA);
    await store.unpin(hashA);
    // Nothing on disk changed -- still exactly the one file `put` wrote.
    expect(dir.listSync().length, 1);
    expect(await store.get(hashA), bytes);

    // An invalid hash is ignored, the same way it is for the other
    // methods.
    await store.pin('../escape');
    await store.unpin('../escape');
    expect(dir.listSync().length, 1);
  });
}
