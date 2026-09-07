import 'package:flutter/material.dart';

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
          Text(title, style: style),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text('$count', style: style?.copyWith(fontWeight: FontWeight.w500)),
          ],
          const Spacer(),
          if (collapsed != null)
            Icon(
              collapsed! ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    if (onToggle == null) return row;
    return InkWell(onTap: onToggle, child: row);
  }
}
