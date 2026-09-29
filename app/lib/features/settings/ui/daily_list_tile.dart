import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The daily list: on or off, and when. Only where reminders exist.
class DailyListTile extends ConsumerWidget {
  const DailyListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(remindersSupportedProvider)) return const SizedBox.shrink();
    final l = L.of(context);
    final enabled = ref.watch(dailyListEnabledProvider);
    final minutes = ref.watch(dailyListMinutesProvider);
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('daily-list-switch'),
          secondary: const AppIcon(Icons.wb_sunny_outlined),
          title: Text(l.dailyListTitle),
          subtitle: Text(l.dailyListHint),
          value: enabled,
          onChanged: (value) async {
            // Like a task's reminder switch: no permission, no switch.
            if (value &&
                !await ref.read(reminderSchedulerProvider).ensurePermission()) {
              return;
            }
            await ref
                .read(dailyListEnabledProvider.notifier)
                .set(enabled: value);
          },
        ),
        ListTile(
          key: const Key('daily-list-time'),
          leading: const SizedBox(width: 24),
          title: Text(l.dailyListTime),
          trailing: Text(time.format(context)),
          enabled: enabled,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked == null) return;
            await ref
                .read(dailyListMinutesProvider.notifier)
                .set(picked.hour * 60 + picked.minute);
          },
        ),
      ],
    );
  }
}
