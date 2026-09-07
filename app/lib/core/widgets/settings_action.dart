import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/shell_screen.dart';

/// App bar button to open settings; hidden when the rail already shows it.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= ShellScreen.railBreakpoint) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: L.of(context).navSettings,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => context.push(Routes.settings),
    );
  }
}
