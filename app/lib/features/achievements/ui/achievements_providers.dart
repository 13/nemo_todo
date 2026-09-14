import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievements_providers.g.dart';

final achievementsRepositoryProvider = Provider<AchievementsRepository>(
  (ref) => AchievementsRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

@riverpod
Stream<CompletionStats> completionStats(Ref ref) =>
    ref.watch(achievementsRepositoryProvider).watchStats();
