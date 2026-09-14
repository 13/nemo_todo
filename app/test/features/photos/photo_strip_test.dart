import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// image_picker re-exports only a handful of names from the platform
// interface, not the ones a fake platform needs to extend -- so this reaches
// past image_picker to its own dependency, which the app does not otherwise
// need to declare directly.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/photos.dart';
import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// Hands back fixed bytes for every pick, so a test can drive `_add`
/// without a real camera or file chooser.
class _FakeImagePicker extends ImagePickerPlatform {
  _FakeImagePicker(this.bytes);

  final Uint8List bytes;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(bytes, name: 'photo.jpg', mimeType: 'image/jpeg');
}

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
      // Seeding runs inside `appTest`'s fake-async zone, where a real
      // isolate's `compute` never reports back.
      process: (raw) async => processPhoto(raw),
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
    // Deleting the only photo leaves nothing to look at, so the pager
    // pops itself rather than sitting empty.
    expect(find.byKey(const Key('photo-viewer')), findsNothing);
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

  appTest('adding a photo disables the button while it processes, and shows it '
      'once done', (tester) async {
    final original = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _FakeImagePicker(smallJpeg());
    addTearDown(() => ImagePickerPlatform.instance = original);
    final completer = Completer<ProcessedPhoto?>();

    await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      photoStore: store,
      seed: seed,
      overrides: [
        // A provider override, not the seeding helper: this add goes
        // through the real `_add` path, so the point of the test is to
        // control when the injected processor resolves.
        photosRepositoryProvider.overrideWith(
          (ref) => PhotosRepository(
            ref.watch(appDatabaseProvider),
            ref.watch(hlcClockProvider),
            ref.watch(idGeneratorProvider),
            ref.watch(photoStoreProvider),
            process: (raw) => completer.future,
          ),
        ),
      ],
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-photos')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhotoThumbnail), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-source-camera')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('photo-add')))
          .onPressed,
      isNull,
      reason: 'processing has not finished yet',
    );

    completer.complete(processPhoto(smallJpeg()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('photo-add')))
          .onPressed,
      isNotNull,
    );
    expect(find.byType(PhotoThumbnail), findsNWidgets(2));
  });
}
