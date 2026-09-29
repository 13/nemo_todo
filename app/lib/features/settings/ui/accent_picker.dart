import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The accent: the style's own first, then its eight list colours.
class AccentPicker extends ConsumerWidget {
  const AccentPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final style = ref.watch(appStyleControllerProvider);
    final chosen = ref.watch(accentControllerProvider);
    final brightness = Theme.of(context).brightness;
    final own = AppTheme.build(style, brightness).colorScheme.primary;
    final names = [
      l.colorTeal,
      l.colorBlue,
      l.colorPurple,
      l.colorPink,
      l.colorRed,
      l.colorOrange,
      l.colorGreen,
      l.colorGrey,
    ];
    void pick(int? accent) =>
        ref.read(accentControllerProvider.notifier).set(accent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsAccent, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Swatch(
                key: const Key('accent-default'),
                color: own,
                label: l.accentDefault,
                selected: chosen == null,
                onTap: () => pick(null),
                // The style's own is marked apart from the list colours.
                icon: Icons.auto_awesome_rounded,
              ),
              for (final (i, color) in AppTheme.accents(style).indexed)
                _Swatch(
                  key: Key('accent-$i'),
                  color: color,
                  label: names[i],
                  selected: chosen == i,
                  onTap: () => pick(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final mark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected
                ? AppIcon(Icons.check_rounded, size: 18, color: mark)
                : icon == null
                ? null
                : AppIcon(icon, size: 16, color: mark),
          ),
        ),
      ),
    );
  }
}
