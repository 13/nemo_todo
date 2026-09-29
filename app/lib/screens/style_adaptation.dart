import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/macos_theme.dart';
import 'package:nemo/screens/shell_screen.dart';

/// Fits the macOS style to the window: a Mac's type where there is room for
/// the sidebar, iOS's where the window is phone-sized -- a 13 pt body is
/// right on a desktop and too small in a hand.
///
/// Sits above every route (in `MaterialApp.builder`), so pages pushed over
/// the shell, like Settings, follow too.
class StyleAdaptation extends StatelessWidget {
  const StyleAdaptation({required this.child, super.key});

  final Widget child;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < ShellScreen.railBreakpoint;

  @override
  Widget build(BuildContext context) {
    if (context.appStyle != AppStyle.macos || !isPhone(context)) return child;
    return Theme(data: MacosTheme.phone(Theme.of(context)), child: child);
  }
}
