import 'package:flutter/material.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';

/// Compact due label coloured by urgency.
class DueChip extends StatelessWidget {
  const DueChip({
    required this.dueAt,
    required this.hasTime,
    required this.now,
    this.done = false,
    super.key,
  });

  final int dueAt;
  final bool hasTime;
  final DateTime now;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue =
        !done && isOverdue(dueAt: dueAt, hasTime: hasTime, now: now);
    final today = daysFromToday(dueAt, now) == 0;
    final color = done
        ? scheme.onSurfaceVariant
        : overdue
        ? context.nemoColors.overdue
        : today
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return MetaChip(
      icon: Icons.schedule_rounded,
      label: dueLabel(
        L.of(context),
        Localizations.localeOf(context).toString(),
        dueAt: dueAt,
        hasTime: hasTime,
        now: now,
      ),
      color: color,
    );
  }
}

/// Icon + short text used in task tiles' meta rows.
class MetaChip extends StatelessWidget {
  const MetaChip({
    required this.icon,
    required this.label,
    this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c),
        ),
      ],
    );
  }
}
