import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
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
Stream<List<Photo>> photosByTask(Ref ref, String taskId) =>
    ref.watch(photosRepositoryProvider).watchByTask(taskId);

@riverpod
Stream<Map<String, int>> photoCounts(Ref ref) =>
    ref.watch(photosRepositoryProvider).watchCounts();

/// The bytes of one picture, or null while this device does not hold them.
@riverpod
Future<Uint8List?> photoBytes(Ref ref, String sha256) =>
    ref.watch(photosRepositoryProvider).bytes(sha256);

/// Pictures this device holds that the server has not taken yet.
@riverpod
Stream<Set<String>> pendingPhotoHashes(Ref ref) =>
    ref.watch(photosRepositoryProvider).watchPendingHashes();
