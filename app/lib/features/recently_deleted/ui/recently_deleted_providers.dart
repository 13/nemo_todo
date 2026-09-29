import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/recently_deleted/data/recently_deleted_repository.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';

final recentlyDeletedRepositoryProvider = Provider<RecentlyDeletedRepository>(
  (ref) => RecentlyDeletedRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    lists: ref.watch(listsRepositoryProvider),
    tasks: ref.watch(tasksRepositoryProvider),
    store: ref.watch(photoStoreProvider),
    now: ref.watch(nowProvider),
  ),
);

/// Tasks deleted in the last 30 days, the most recently deleted first.
final recentlyDeletedProvider = StreamProvider<List<DeletedTask>>(
  (ref) => ref.watch(recentlyDeletedRepositoryProvider).watch(),
);

/// Lists deleted in the last 30 days that this account can bring back, the
/// most recently deleted first.
final recentlyDeletedListsProvider = StreamProvider<List<DeletedList>>(
  (ref) => ref.watch(recentlyDeletedRepositoryProvider).watchLists(),
);
