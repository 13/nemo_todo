import 'package:flutter/material.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Announces one or more unlocked achievements; tap to see them all.
class AchievementBanner extends StatelessWidget {
  const AchievementBanner({
    required this.achievements,
    required this.onOpen,
    required this.onClose,
    super.key,
  });

  final List<Achievement> achievements;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final single = achievements.length == 1 ? achievements.single : null;
    final headline =
        single?.title(l) ?? l.achievementsUnlockedMany(achievements.length);
    return Semantics(
      liveRegion: true,
      child: Material(
        key: const Key('achievement-banner'),
        color: scheme.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                Icon(
                  single?.icon ?? Icons.emoji_events_rounded,
                  size: 32,
                  color: scheme.inversePrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.achievementUnlockedBanner,
                        style: text.labelMedium?.copyWith(
                          color: scheme.onInverseSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        headline,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.commonClose,
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: scheme.onInverseSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
