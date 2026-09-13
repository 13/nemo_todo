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

  File fileFor(String sha256) => File(
    '$root/${sha256.substring(0, 2)}/${sha256.substring(2, 4)}/$sha256',
  );

  Future<bool> exists(String sha256) => fileFor(sha256).exists();

  Future<void> write(String sha256, List<int> bytes) async {
    final file = fileFor(sha256);
    await file.parent.create(recursive: true);
    // Written beside the target and renamed, so a request cut off halfway
    // never leaves a short file under a hash that promises the whole one.
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }

  Stream<List<int>> read(String sha256) => fileFor(sha256).openRead();

  Future<void> delete(String sha256) async {
    final file = fileFor(sha256);
    if (await file.exists()) await file.delete();
  }
}
