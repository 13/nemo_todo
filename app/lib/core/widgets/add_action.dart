import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/widgets/app_icon.dart';

/// A screen's one way to add something, where its style puts it: a
/// floating button in Material's styles, a plain + in the toolbar in the
/// macOS style, where nothing floats over the content.
///
/// A screen puts [toolbar] first among its app bar's actions and [fab] as
/// its floating action button; in each style one of them is null.
class AddAction {
  const AddAction({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.extended = false,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  /// Whether the floating button carries [label] beside its +.
  final bool extended;

  Widget? toolbar(BuildContext context) => context.appStyle != AppStyle.macos
      ? null
      : IconButton(
          key: buttonKey,
          tooltip: label,
          icon: const AppIcon(Icons.add_rounded),
          onPressed: onPressed,
        );

  Widget? fab(BuildContext context) {
    if (context.appStyle == AppStyle.macos) return null;
    return extended
        ? FloatingActionButton.extended(
            key: buttonKey,
            onPressed: onPressed,
            icon: const AppIcon(Icons.add_rounded),
            label: Text(label),
          )
        : FloatingActionButton(
            key: buttonKey,
            tooltip: label,
            onPressed: onPressed,
            child: const AppIcon(Icons.add),
          );
  }
}
