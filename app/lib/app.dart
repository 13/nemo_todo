import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
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
  void initState() {
    super.initState();
    // The stored session is read after the first frame is scheduled, so a
    // cold start never waits on the platform keychain.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authControllerProvider.notifier).restore();
      if (!mounted) return;
      ref
          .read(syncEngineProvider.notifier)
          .requestSync(delay: const Duration(milliseconds: 200));
      // Quiet unless something is actually newer, and at most daily.
      unawaited(ref.read(updateControllerProvider.notifier).check());
    });
  }

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
      builder: (context, child) =>
          SyncLifecycleObserver(child: child ?? const SizedBox.shrink()),
    );
  }
}
