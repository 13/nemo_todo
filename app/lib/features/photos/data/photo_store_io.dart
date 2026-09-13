import 'dart:io';
import 'dart:typed_data';

import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:path_provider/path_provider.dart';

/// Pictures as files, named by content, under the app's support directory.
class FilePhotoStore implements PhotoStore {
  FilePhotoStore(this.directory);

  final String directory;

  // Exactly lowercase hex, exactly 64 characters: what a SHA-256 hex digest
  // always looks like. `_file` builds a path by interpolating this string
  // with no escaping of its own, so anything let through here is a path a
  // corrupted or malicious row gets to choose; the server validates the
  // same shape on the way in, but this device doesn't get to rely on that.
  static final RegExp _hashPattern = RegExp(r'^[0-9a-f]{64}$');

  static int _tempSequence = 0;

  File _file(String sha256) => File('$directory/$sha256.jpg');

  @override
  Future<void> put(String sha256, Uint8List bytes) async {
    if (!_hashPattern.hasMatch(sha256)) {
      throw ArgumentError.value(sha256, 'sha256', 'not a sha-256 hex digest');
    }
    final file = _file(sha256);
    await file.parent.create(recursive: true);
    // Its own temp file beside the target, never a shared one: two
    // concurrent puts of the same hash -- an interrupted download simply
    // retried -- each rename their own file onto the target instead of
    // racing to rename one they'd share, and since both hold the same
    // bytes it doesn't matter which rename lands last.
    final temp = File('${file.path}.${_tempSequence++}.part');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } on FileSystemException {
      try {
        await temp.delete();
      } on PathNotFoundException {
        // Nothing was left behind to clean up.
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List?> get(String sha256) async {
    if (!_hashPattern.hasMatch(sha256)) return null;
    try {
      return await _file(sha256).readAsBytes();
    } on PathNotFoundException {
      return null;
    }
  }

  @override
  Future<void> remove(String sha256) async {
    if (!_hashPattern.hasMatch(sha256)) return;
    try {
      await _file(sha256).delete();
    } on PathNotFoundException {
      // Removing what is not there is not an error: two deletes can race.
    }
  }

  // Files on disk are never evicted, so there is nothing for pinning to
  // protect -- both are unconditional no-ops, which incidentally keeps
  // them consistent with `remove`'s hash guard: an invalid hash is
  // ignored here too, the same as it would be if we checked.
  @override
  Future<void> pin(String sha256) async {}

  @override
  Future<void> unpin(String sha256) async {}
}

Future<PhotoStore> createPhotoStore() async {
  final support = await getApplicationSupportDirectory();
  return FilePhotoStore('${support.path}/photos');
}
