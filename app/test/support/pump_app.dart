import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import 'test_db.dart';

/// Containers [pumpApp] built for the test running right now, so [appTest]
/// can close them while the framework is still watching.
final _open = <ProviderContainer>[];

/// A widget test that tears its tree down inside the test body.
///
/// Closing a drift stream schedules a zero-duration timer, and the tree
/// that flutter_test disposes on its own is torn down too late for that
/// timer to run before the framework checks that none are pending. Pumping
/// an empty tree here, then two more frames, keeps that check honest.
///
/// The container goes the same way, and for the same reason: a keepAlive
/// provider outlives the tree, and the sync engine holds a timer for the
/// next attempt after a failure. `addTearDown` would cancel it a moment
/// after the framework has already counted it as leaked.
@isTest
void appTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final container in _open.toList()) {
      if (_open.remove(container)) container.dispose();
    }
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}

typedef TestApp = ({
  AppDatabase db,
  GoRouter router,
  TaskList inbox,
  ProviderContainer container,
});

/// The app over a fresh in-memory database, routed to [initialLocation].
///
/// Mirrors `main.dart` and `NemoApp`: the inbox exists before the first
/// frame, settings come from the database, and a stored session is
/// restored once the tree is up.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  String initialLocation = Routes.today,
  // Riverpod does not export the type of its overrides, so the element
  // type is recovered from the list literal below with `cast()`.
  List<Object> overrides = const [],
  Size size = const Size(400, 800),
  Future<void> Function(AppDatabase db, TaskList inbox)? seed,
  // Screens showing sync status animate a progress indicator, which never
  // lets `pumpAndSettle` return. Those tests pump a fixed number of frames.
  bool settle = true,
}) async {
  final db = testDatabase();
  addTearDown(db.close);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final inbox = await ListsRepository(
    db,
    testClock('seed'),
    sequentialIds('l'),
  ).ensureInbox();
  await seed?.call(db, inbox);
  final boot = await AppBootstrap.load(db);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bootstrapProvider.overrideWithValue(boot),
      nowProvider.overrideWithValue(() => testNow),
      idGeneratorProvider.overrideWithValue(sequentialIds()),
      ...overrides.cast(),
    ],
  );
  _open.add(container);
  addTearDown(() {
    if (_open.remove(container)) container.dispose();
  });

  final router = AppRouter.router(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ref.watch(themeModeControllerProvider),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          routerConfig: router,
        ),
      ),
    ),
  );
  await container.read(authControllerProvider.notifier).restore();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await settleSync(tester);
  }
  return (db: db, router: router, inbox: inbox, container: container);
}

/// Advances past the sync debounce and lets a round trip finish, without
/// waiting for animations that never end.
Future<void> settleSync(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Types into the quick-add field and submits it.
Future<void> quickAdd(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(const Key('quick-add-field')), title);
  await tester.tap(find.byKey(const Key('quick-add-submit')));
  await tester.pumpAndSettle();
}
