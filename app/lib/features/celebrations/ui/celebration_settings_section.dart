import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// The switches that make nemo cheer, or keep it quiet and professional.
class CelebrationSettingsSection extends ConsumerWidget {
  const CelebrationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final celebrate = ref.watch(celebrationsEnabledProvider);
    final sound = ref.watch(celebrationSoundEnabledProvider);
    final showAchievements = ref.watch(achievementsEnabledProvider);
    final stats = showAchievements
        ? ref.watch(completionStatsProvider).value
        : null;
    final unlocked = stats == null
        ? null
        : progressOf(stats).where((p) => p.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.settingsCelebrations),
        SwitchListTile(
          key: const Key('celebrations-switch'),
          secondary: const Icon(Icons.celebration_outlined),
          title: Text(l.settingsCelebrationsEnabled),
          subtitle: Text(l.settingsCelebrationsEnabledHint),
          value: celebrate,
          onChanged: (v) =>
              ref.read(celebrationsEnabledProvider.notifier).set(enabled: v),
        ),
        SwitchListTile(
          key: const Key('celebration-sound-switch'),
          secondary: const Icon(Icons.volume_up_outlined),
          title: Text(l.settingsCelebrationSound),
          subtitle: Text(l.settingsCelebrationSoundHint),
          value: sound,
          // Sound belongs to celebrating; without it there is nothing to
          // play along to.
          onChanged: celebrate
              ? (v) => ref
                    .read(celebrationSoundEnabledProvider.notifier)
                    .set(enabled: v)
              : null,
        ),
        SwitchListTile(
          key: const Key('achievements-switch'),
          secondary: const Icon(Icons.emoji_events_outlined),
          title: Text(l.settingsAchievements),
          subtitle: Text(l.settingsAchievementsHint),
          value: showAchievements,
          onChanged: (v) =>
              ref.read(achievementsEnabledProvider.notifier).set(enabled: v),
        ),
        if (showAchievements)
          ListTile(
            key: const Key('achievements-tile'),
            leading: const SizedBox(width: 24),
            title: Text(l.achievementsView),
            subtitle: unlocked == null
                ? null
                : Text(
                    l.achievementsUnlockedCount(
                      unlocked,
                      achievementCatalog.length,
                    ),
                  ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.achievements),
          ),
      ],
    );
  }
}
