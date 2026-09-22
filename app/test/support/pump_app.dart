import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/auth/ui/auth_guard.dart';
import 'package:nemo/features/celebrations/data/celebration_sound.dart';
import 'package:nemo/features/celebrations/ui/celebration_overlay.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/features/settings/data/server_build.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import 'fake_celebrations.dart';
import 'photos.dart';
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
void appTest(
  String description,
  Future<void> Function(WidgetTester) body, {
  Object? tags,
}) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final container in _open.toList()) {
      if (_open.remove(container)) container.dispose();
    }
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }, tags: tags);
}

typedef TestApp = ({
  AppDatabase db,
  GoRouter router,
  TaskList inbox,
  ProviderContainer container,
});

/// Seed helpers for a running [pumpApp], writing straight to its database
/// the way a screen test wants rows to already exist rather than exercising
/// a repository's own creation flow.
extension SeedTestApp on TestApp {
  Future<void> seedList(String id, String name) => db.upsertList(
    TaskList(
      id: id,
      name: name,
      sortKey: SortKey.first(),
      updatedAt: testClock('a').now().toString(),
    ),
  );

  Future<void> seedNote(
    String id,
    String listId, {
    required String title,
    String body = '',
    bool pinned = false,
  }) => db.upsertNote(
    Note(
      id: id,
      listId: listId,
      title: title,
      body: body,
      pinned: pinned,
      sortKey: 'V',
      updatedAt: testClock('a').now().toString(),
    ),
  );

  /// Adds a picture straight through the repository, the way [seedList] and
  /// [seedNote] write rows directly rather than driving the picker UI a
  /// widget test would otherwise have to fake.
  ///
  /// Uses the same [photoStoreProvider] the running app was wired with --
  /// not a store of its own -- so a widget that reads the picture back
  /// through that provider (a thumbnail, the strip) finds its bytes.
  Future<void> addPhotoTo(PhotoParent kind, String parentId) =>
      PhotosRepository(
        db,
        testClock('a'),
        sequentialIds('p'),
        container.read(photoStoreProvider),
        // Runs inside appTest's fake-async zone, where a real isolate's
        // `compute` never reports back.
        process: (raw) async => processPhoto(raw),
      ).add(kind, parentId, smallJpeg());
}

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
  PhotoStore? photoStore,
  // Celebrations are on in the app. Most tests tick tasks off and look at
  // what follows, which a banner over the app bar would get in the way of,
  // so they start off unless a test is about them.
  bool celebrate = false,
  CelebrationSound? sound,
  // The app's clock; [testNow] unless a test is about a particular day.
  DateTime? now,
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
  if (!celebrate) {
    await KvStore(db).set(KvKeys.celebrations, 'false');
    await KvStore(db).set(KvKeys.achievements, 'false');
  }
  await seed?.call(db, inbox);
  final boot = await AppBootstrap.load(db);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bootstrapProvider.overrideWithValue(boot),
      nowProvider.overrideWithValue(() => now ?? testNow),
      idGeneratorProvider.overrideWithValue(sequentialIds()),
      // Opened in `main` in the app; a connected sync reads it.
      photoStoreProvider.overrideWithValue(photoStore ?? MemoryPhotoStore()),
      // The audio plugin has no test implementation.
      celebrationSoundProvider.overrideWithValue(
        sound ?? RecordingCelebrationSound(),
      ),
      // The About tile asks a connected server how it was built; a test's
      // server is a fake, and a real request would outlive the test.
      serverBuildFetcherProvider.overrideWithValue((_) async => null),
      ...overrides.cast(),
    ],
  );
  _open.add(container);
  addTearDown(() {
    if (_open.remove(container)) container.dispose();
  });

  // Wired the way `NemoApp` wires it: the guard drives the router only
  // where an account is required, which a test asks for by overriding
  // `authRequiredProvider` the way the web build sets it.
  final guarded = container.read(authRequiredProvider);
  final session = ValueNotifier<int>(0);
  addTearDown(session.dispose);
  if (guarded) {
    container.listen(authControllerProvider, (_, _) => session.value++);
  }
  final router = AppRouter.router(
    initialLocation: initialLocation,
    refreshListenable: guarded ? session : null,
    redirect: guarded
        ? (context, state) => AuthGuard.redirect(
            required: true,
            restored: container.read(authControllerProvider).restored,
            connected: container.read(authControllerProvider).connected,
            location: state.uri,
          )
        : null,
  );
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
          builder: (context, child) => CelebrationOverlay(
            onOpenAchievements: () =>
                unawaited(router.push(Routes.achievements)),
            child: child ?? const SizedBox.shrink(),
          ),
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

/// Scrolls the first scrollable until [finder] can actually be tapped.
///
/// `ensureVisible` does nothing for a widget that is built but below the
/// fold, and `scrollUntilVisible` stops as soon as the widget exists; asking
/// for a hit-testable match keeps scrolling until it is really on screen.
Future<void> scrollIntoView(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder.hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );

/// Types into the quick-add field and submits it.
Future<void> quickAdd(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(const Key('quick-add-field')), title);
  await tester.tap(find.byKey(const Key('quick-add-submit')));
  await tester.pumpAndSettle();
}
