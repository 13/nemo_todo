import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final stats = ref.watch(completionStatsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.achievementsTitle)),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : MaxWidth(
              child: Builder(
                builder: (context) {
                  final items = progressOf(stats);
                  final unlocked = items.where((p) => p.unlocked).length;
                  final text = Theme.of(context).textTheme;
                  final scheme = Theme.of(context).colorScheme;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l.achievementsUnlockedCount(
                                  unlocked,
                                  items.length,
                                ),
                                style: text.titleMedium,
                              ),
                              if (stats.currentStreak > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 20,
                                      color: scheme.tertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l.achievementsStreak(stats.currentStreak),
                                      style: text.bodyMedium,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => AchievementCard(progress: items[i]),
                            childCount: items.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

/// One achievement: full colour once reached, muted with progress before.
class AchievementCard extends StatelessWidget {
  const AchievementCard({required this.progress, super.key});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = progress.achievement;
    final on = progress.unlocked;
    final status = on
        ? l.achievementsUnlocked
        : l.achievementsProgress(progress.shown, a.target);
    return Semantics(
      key: Key('achievement-${a.id}'),
      label: '${a.title(l)}. ${a.description(l)}. $status',
      excludeSemantics: true,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                a.icon,
                size: 36,
                color: on
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                a.title(l),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  a.description(l),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: on
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!on) ...[
                LinearProgressIndicator(
                  value: progress.fraction,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
              ],
              Text(status, style: text.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
