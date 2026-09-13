import 'dart:typed_data';

import 'package:nemo/features/photos/data/photo_store_web.dart'
    if (dart.library.io) 'package:nemo/features/photos/data/photo_store_io.dart';

/// Where the bytes of a picture live on this device.
///
/// Two implementations, chosen at compile time the way the certificate
/// trust adapter is: files on Android, memory on the web -- where there is
/// nothing worth persisting to, and where the browser may not be the
/// user's own.
abstract interface class PhotoStore {
  Future<void> put(String sha256, Uint8List bytes);
  Future<Uint8List?> get(String sha256);
  Future<void> remove(String sha256);
}

/// The store this platform uses. On Android the directory is created on
/// first use under the app's support directory.
Future<PhotoStore> openPhotoStore() => createPhotoStore();
