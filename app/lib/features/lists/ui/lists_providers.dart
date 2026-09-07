import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lists_providers.g.dart';

final listsRepositoryProvider = Provider<ListsRepository>(
  (ref) => ListsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

@riverpod
Stream<List<TaskList>> allLists(Ref ref) =>
    ref.watch(listsRepositoryProvider).watchAll();

@riverpod
Stream<TaskList?> listById(Ref ref, String id) =>
    ref.watch(listsRepositoryProvider).watch(id);

/// Sharing metadata by list id, as last reported by the server.
@riverpod
Stream<Map<String, ListSharing>> listMeta(Ref ref) =>
    ref.watch(appDatabaseProvider).watchListMeta();
