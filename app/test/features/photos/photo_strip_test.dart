import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/photos.dart';
import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  late MemoryPhotoStore store;

  setUp(() => store = MemoryPhotoStore());

  Future<void> seed(AppDatabase db, TaskList inbox) async {
    await db.upsertTask(
      Task(
        id: 't1',
        listId: inbox.id,
        title: 'Broken tap',
        sortKey: 'V',
        updatedAt: testClock('a').now().toString(),
      ),
    );
    await PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    ).add('t1', smallJpeg());
  }

  appTest('the strip shows a task photo and deletes it from the viewer', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      photoStore: store,
      seed: seed,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-photos')),
      200,
      // The subtask list is a scrollable of its own, so the one to drive
      // has to be named rather than guessed at.
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-p1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-viewer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-viewer-delete')));
    await tester.pumpAndSettle();
    expect((await app.db.photoById('p1'))!.isDeleted, isTrue);
    expect(find.byKey(const Key('photo-p1')), findsNothing);
  });

  appTest('a task with photos shows one on its tile', (tester) async {
    final app = await pumpApp(tester, photoStore: store, seed: seed);
    // Today shows only what is due today; the task lives in the inbox.
    app.router.go(Routes.list(app.inbox.id));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tile-photo-t1')), findsOneWidget);
  });

  appTest(
    'an unrecognised server refusal code shows nothing, never a raw code',
    (tester) async {
      await pumpApp(
        tester,
        initialLocation: Routes.task('t1'),
        photoStore: store,
        seed: seed,
        overrides: [
          syncEngineProvider.overrideWithValue(
            const SyncState(photoError: 'a_new_code'),
          ),
        ],
      );

      expect(find.byKey(const Key('photo-refusal')), findsNothing);
      expect(find.text('a_new_code'), findsNothing);
    },
  );
}
