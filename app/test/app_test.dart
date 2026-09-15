import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/app.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/celebrations/data/celebration_sound.dart';
import 'package:nemo/features/celebrations/ui/celebration_overlay.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/settings/data/server_build.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/tasks/ui/today_screen.dart';

import 'support/fake_celebrations.dart';
import 'support/fake_sync.dart';
import 'support/test_db.dart';

/// The app as `main` starts it -- not the copy of its wiring `pumpApp`
/// builds -- so a change to the router, the guard or the builder is caught.
void main() {
  Future<ProviderContainer> pumpNemoApp(
    WidgetTester tester, {
    bool authRequired = false,
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    final db = testDatabase();
    addTearDown(db.close);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await ListsRepository(
      db,
      testClock('seed'),
      sequentialIds('l'),
    ).ensureInbox();
    await seed?.call(db);
    final boot = await AppBootstrap.load(db);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
        nowProvider.overrideWithValue(() => testNow),
        idGeneratorProvider.overrideWithValue(sequentialIds()),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        serverBuildFetcherProvider.overrideWithValue((_) async => null),
        celebrationSoundProvider.overrideWithValue(RecordingCelebrationSound()),
        // The start-up update check must not reach GitHub from a test.
        updatesSupportedProvider.overrideWithValue(false),
        authRequiredProvider.overrideWithValue(authRequired),
        authStorageProvider.overrideWithValue(MemoryAuthStorage()),
        syncClientFactoryProvider.overrideWithValue(
          (_, _) => FakeSyncClient([]),
        ),
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const NemoApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Tears the tree and container down inside the test, as `appTest` does,
  /// so drift's close timers run before the framework checks for them.
  Future<void> finish(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('opens on Today as nemo todo, with celebrations mounted', (
    tester,
  ) async {
    final container = await pumpNemoApp(tester);

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(tester.widget<Title>(find.byType(Title).first).title, 'nemo todo');
    expect(find.byType(CelebrationOverlay), findsOneWidget);
    expect(container.read(authControllerProvider).restored, isTrue);

    await finish(tester, container);
  });

  testWidgets('follows a stored dark theme', (tester) async {
    final container = await pumpNemoApp(
      tester,
      seed: (db) => KvStore(db).set(KvKeys.themeMode, 'dark'),
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await finish(tester, container);
  });

  testWidgets('where an account is required, asks for one first', (
    tester,
  ) async {
    final container = await pumpNemoApp(tester, authRequired: true);

    expect(find.byKey(const Key('account-sign-in')), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);

    await finish(tester, container);
  });
}
