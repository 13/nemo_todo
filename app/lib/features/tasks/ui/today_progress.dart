import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/celebrations/ui/motivation_text.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// The Today screen's own progress: a bar and a count of what is done, plus
/// -- while Celebrations is on -- a calm line about where the day stands.
class TodayProgress extends ConsumerWidget {
  const TodayProgress({required this.items, super.key});

  /// Today's tasks as the Today screen already has them: open tasks due
  /// today or earlier, plus whatever was completed today.
  final List<Task> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = items.length;
    if (total == 0) return const SizedBox.shrink();
    final done = items.where((t) => t.done).length;
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final line = ref.watch(celebrationsEnabledProvider)
        ? _line(ref, l: l, done: done, total: total)
        : null;
    return Padding(
      key: const Key('today-progress'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  key: const Key('today-progress-bar'),
                  value: done / total,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.todayProgressCount(done, total),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: onSurfaceVariant),
              ),
            ],
          ),
          if (line != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                line,
                key: const Key('today-progress-line'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  /// The line's words, or null when today has none. Loading stats reads as
  /// no last completion, which gives a fresh-start line rather than one
  /// that first has to wait on the database.
  String? _line(
    WidgetRef ref, {
    required L l,
    required int done,
    required int total,
  }) {
    final now = ref.watch(nowProvider)();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    if (done == total) {
      return todayLineText(l, TodayLine.allClear, dayOfYear);
    }
    if (done == 0) {
      final lastDoneAt = ref.watch(completionStatsProvider).value?.lastDoneAt;
      // Negative: the last completion's day is before today's. Stepped by
      // calendar date rather than by 24-hour spans, the same reasoning
      // `daysFromToday` documents for streaks around a daylight-saving day.
      final welcomeBack =
          lastDoneAt != null && daysFromToday(lastDoneAt, now) <= -3;
      return todayLineText(
        l,
        welcomeBack ? TodayLine.welcomeBack : TodayLine.freshStart,
        dayOfYear,
      );
    }
    return null;
  }
}
