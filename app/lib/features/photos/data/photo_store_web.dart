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

  // Hashes currently exempt from eviction -- bytes with no other copy
  // yet (a web upload still in flight) that would otherwise be lost for
  // good if they aged out while nothing was looking at them. A hash can
  // be pinned before it is ever put, so this can hold hashes `_entries`
  // doesn't (yet).
  final _pinned = <String>{};

  @override
  Future<void> put(String sha256, Uint8List bytes) async {
    _entries
      ..remove(sha256)
      ..[sha256] = bytes;
    _evict();
  }

  @override
  Future<Uint8List?> get(String sha256) async {
    final bytes = _entries.remove(sha256);
    if (bytes != null) _entries[sha256] = bytes;
    return bytes;
  }

  @override
  Future<void> remove(String sha256) async {
    _entries.remove(sha256);
    _pinned.remove(sha256);
  }

  @override
  Future<void> pin(String sha256) async {
    // Recorded even if `sha256` isn't held yet, so a `put` that follows
    // finds it already protected.
    _pinned.add(sha256);
  }

  @override
  Future<void> unpin(String sha256) async {
    _pinned.remove(sha256);
    // The entry (if any) may now be over the bound it was exempt from.
    _evict();
  }

  // Removes the least-recently-used *unpinned* entry, repeatedly, until
  // unpinned entries are within maxEntries or none are left to remove.
  // Pinned entries are never counted against the bound, so the store may
  // temporarily hold more than maxEntries entries in total while any are
  // pinned -- that's the point: bytes with no other copy yet must survive
  // however full the store gets.
  void _evict() {
    while (_entries.keys.where((hash) => !_pinned.contains(hash)).length >
        maxEntries) {
      final victim = _entries.keys.firstWhere(
        (hash) => !_pinned.contains(hash),
      );
      _entries.remove(victim);
    }
  }
}

Future<PhotoStore> createPhotoStore() async => MemoryPhotoStore();
