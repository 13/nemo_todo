import 'dart:typed_data';

import 'package:nemo/features/photos/data/photo_store.dart';

/// Pictures in memory, most recently used kept.
///
/// The web app is served by the server it syncs with and is never offline
/// for long, so bytes are fetched when a picture is shown rather than kept
/// -- and a browser that may be shared is not somewhere to leave someone's
/// photographs behind.
class MemoryPhotoStore implements PhotoStore {
  MemoryPhotoStore({this.maxEntries = 40});

  final int maxEntries;
  // A plain `{}` literal is already insertion-ordered (it's a
  // LinkedHashMap under the hood), which is what lets `keys.first` below
  // find the least recently used entry.
  final _entries = <String, Uint8List>{};

  @override
  Future<void> put(String sha256, Uint8List bytes) async {
    _entries
      ..remove(sha256)
      ..[sha256] = bytes;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  Future<Uint8List?> get(String sha256) async {
    final bytes = _entries.remove(sha256);
    if (bytes != null) _entries[sha256] = bytes;
    return bytes;
  }

  @override
  Future<void> remove(String sha256) async => _entries.remove(sha256);
}

Future<PhotoStore> createPhotoStore() async => MemoryPhotoStore();
