import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photos_providers.g.dart';

final photosRepositoryProvider = Provider<PhotosRepository>(
  (ref) => PhotosRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(photoStoreProvider),
  ),
);

@riverpod
Stream<List<Photo>> photosByParent(Ref ref, PhotoParent kind, String id) =>
    ref.watch(photosRepositoryProvider).watchByParent(kind, id);

@riverpod
Stream<Map<String, int>> photoCounts(Ref ref) =>
    ref.watch(photosRepositoryProvider).watchCounts();

/// The bytes of one picture, or null while nobody can hand them over.
///
/// Where downloads are not eager -- the web -- bytes the store does not
/// hold are fetched here, when the picture is shown: nothing else would
/// ever bring in a picture from another device, one the in-memory store
/// evicted, or any of them after a reload.
@riverpod
Future<Uint8List?> photoBytes(Ref ref, String sha256) async {
  // Everything read up front: an autoDispose provider may be gone by the
  // time the awaits below come back.
  final repository = ref.watch(photosRepositoryProvider);
  final eager = ref.watch(photoDownloadEagerProvider);
  final store = ref.watch(photoStoreProvider);
  final db = ref.watch(appDatabaseProvider);
  final client = _client(ref);
  final held = await repository.bytes(sha256);
  if (held != null || eager || client == null) return held;
  try {
    final bytes = await client.downloadBlob(sha256);
    await store.put(sha256, bytes);
    await db.rememberBlob(sha256, byteSize: bytes.length, state: 'synced');
    return bytes;
  } on ApiError {
    // Offline, or not a picture this account can see: the placeholder
    // says as much, and the next time it is shown asks again.
    return null;
  }
}

SyncClient? _client(Ref ref) {
  final auth = ref.read(authControllerProvider);
  if (!auth.connected) return null;
  return ref.read(syncClientFactoryProvider)(auth.serverUrl!, auth.token!);
}

/// Pictures this device holds that the server has not taken yet.
@riverpod
Stream<Set<String>> pendingPhotoHashes(Ref ref) =>
    ref.watch(photosRepositoryProvider).watchPendingHashes();
