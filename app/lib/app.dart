import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/auth/ui/auth_guard.dart';
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
  /// Whether this build shows anything before someone signs in.
  late final bool _guarded = ref.read(authRequiredProvider);

  /// Bumped whenever the session changes, so the router asks the guard
  /// again: signing in leaves the sign-in screen, signing out returns to
  /// it, without either screen having to know about routing.
  ///
  /// Only where the guard has something to say. A refresh re-resolves the
  /// location from the route table, which would undo a pushed screen --
  /// and the local-first build pushes the Connect screen and pops it again
  /// the moment the session appears.
  final _session = ValueNotifier<int>(0);

  late final GoRouter _router = AppRouter.router(
    initialLocation: _guarded ? Routes.starting : Routes.today,
    refreshListenable: _guarded ? _session : null,
    redirect: _guarded
        ? (context, state) => AuthGuard.redirect(
            required: true,
            restored: ref.read(authControllerProvider).restored,
            connected: ref.read(authControllerProvider).connected,
            location: state.uri,
          )
        : null,
  );

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
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_guarded) {
      ref.listen(authControllerProvider, (_, _) => _session.value++);
    }
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
