import 'package:flutter/material.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Small caps-style label above a group of tiles, optionally collapsible.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.count,
    this.collapsed,
    this.onToggle,
    this.color,
    super.key,
  });

  final String title;
  final int? count;
  final bool? collapsed;
  final VoidCallback? onToggle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: color ?? scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(title, style: style)),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: style?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          if (collapsed != null)
            AppIcon(
              collapsed! ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    final folded = collapsed;
    if (onToggle == null) return row;
    final l = L.of(context);
    // Says whether the section is open and what a tap will do to it.
    return Semantics(
      button: true,
      expanded: folded == null ? null : !folded,
      onTapHint: folded == null
          ? null
          : folded
          ? l.a11yExpand
          : l.a11yCollapse,
      // A finger's height, the room below the title.
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: row,
        ),
      ),
    );
  }
}
