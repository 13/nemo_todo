import 'package:flutter/material.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
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
      // Every colour here is one text can be read in, and overdue is the
      // one fact on a tile worth seeing before reading anything else.
      tintLabel: true,
    );
  }
}

/// Icon + short text used in task tiles' meta rows.
///
/// [color] always colours the icon; it colours the text too where the
/// style says so (`NemoColors.tintedMetaText`) or [tintLabel] asks, since
/// a list's colour is often too light to read small text in.
class MetaChip extends StatelessWidget {
  const MetaChip({
    required this.icon,
    required this.label,
    this.color,
    this.tintLabel = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool tintLabel;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final c = color ?? secondary;
    final text = tintLabel || context.nemoColors.tintedMetaText ? c : secondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: text),
        ),
      ],
    );
  }
}
