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
}
