import 'dart:io';

import 'package:crypto/crypto.dart';

/// The bytes of every picture the server holds, on disk, named by content.
///
/// A hash is the whole identity: the same picture uploaded twice is one
/// file, and a file can never be the wrong bytes for its name. The two
/// levels of directory keep any one directory from growing to the size of
/// the whole store.
class BlobStore {
  BlobStore(this.root);

  final String root;

  static String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

  File fileFor(String sha256) =>
      File('$root/${sha256.substring(0, 2)}/${sha256.substring(2, 4)}/$sha256');

  // A single stat, done synchronously: the async File.exists() goes
  // through an inefficient platform implementation for this, so there is
  // no async version worth awaiting instead.
  Future<bool> exists(String sha256) async => fileFor(sha256).existsSync();

  static int _tempSequence = 0;

  Future<void> write(String sha256, List<int> bytes) async {
    final file = fileFor(sha256);
    await file.parent.create(recursive: true);
    // Every call gets its own temp file beside the target, never a shared
    // one, so two concurrent writes of the same hash - an interrupted
    // upload simply repeated, or the same photo sent by two people at
    // once - each rename their own file onto the target instead of
    // racing to rename one they'd otherwise share. Whichever rename lands
    // last wins, and since both hold the same bytes it doesn't matter
    // which.
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

  Stream<List<int>> read(String sha256) => fileFor(sha256).openRead();

  Future<void> delete(String sha256) async {
    final file = fileFor(sha256);
    try {
      await file.delete();
    } on PathNotFoundException {
      // Deleting what is not there is not an error: a sweep may race a
      // delete that already happened.
    }
  }
}
