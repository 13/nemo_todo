import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import 'test_db.dart';

/// A widget test that tears its tree down inside the test body.
///
/// Closing a drift stream schedules a zero-duration timer, and the tree
/// that flutter_test disposes on its own is torn down too late for that
/// timer to run before the framework checks that none are pending. Pumping
/// an empty tree here, then one more frame, keeps that check honest.
@isTest
void appTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    // Two frames with time on the clock: the first unmounts the provider
    // scope, the second lets the timers that unmount scheduled expire.
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}

/// The app over a fresh in-memory database, routed to [initialLocation].
Future<({AppDatabase db, GoRouter router, TaskList inbox})> pumpApp(
  WidgetTester tester, {
  String initialLocation = Routes.today,
  // Riverpod does not export the type of its overrides, so the element
  // type is recovered from the list literal below with `cast()`.
  List<Object> overrides = const [],
  Size size = const Size(400, 800),
  Future<void> Function(AppDatabase db, TaskList inbox)? seed,
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

  final router = AppRouter.router(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(
          const AppBootstrap(
            nodeId: 'test',
            hlcLast: null,
            themeMode: ThemeMode.light,
          ),
        ),
        nowProvider.overrideWithValue(() => testNow),
        idGeneratorProvider.overrideWithValue(sequentialIds()),
        ...overrides.cast(),
      ],
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
  await tester.pumpAndSettle();
  return (db: db, router: router, inbox: inbox);
}

/// Types into the quick-add field and submits it.
Future<void> quickAdd(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(const Key('quick-add-field')), title);
  await tester.tap(find.byKey(const Key('quick-add-submit')));
  await tester.pumpAndSettle();
}
