import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/l10n/locale_resolution.dart';

/// Shown when the local database cannot be opened.
///
/// Without it the app would sit on a blank screen: a browser that blocks
/// site data leaves the database waiting rather than failing, and a user
/// staring at nothing has no idea why.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => L.of(context).appName,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    localeResolutionCallback: resolveAppLocale,
    home: StartupErrorScreen(error: error),
  );
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NemoLogoTile(size: 64),
              const SizedBox(height: 24),
              Text(
                l.startupErrorTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l.startupErrorBody,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SelectableText(
                '$error',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
