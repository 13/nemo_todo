import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/l10n/locale_resolution.dart';
import 'package:nemo/router.dart';

class NemoApp extends ConsumerStatefulWidget {
  const NemoApp({super.key});

  @override
  ConsumerState<NemoApp> createState() => _NemoAppState();
}

class _NemoAppState extends ConsumerState<NemoApp> {
  late final GoRouter _router = AppRouter.router();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => L.of(context).appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeControllerProvider),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      localeResolutionCallback: resolveAppLocale,
      routerConfig: _router,
    );
  }
}
