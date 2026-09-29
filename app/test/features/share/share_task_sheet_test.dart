import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/features/share/data/shared_content.dart';
import 'package:nemo/features/share/ui/share_task_sheet.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/photos.dart';
import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  /// The app with the sheet opened over it for [draft]; the future is what
  /// the sheet popped with.
  Future<(TestApp, Future<bool?>)> openSheet(
    WidgetTester tester,
    ShareDraft draft,
  ) async {
    final app = await pumpApp(
      tester,
      overrides: [
        // compute()'s isolate never reports back inside a widget test's
        // fake clock; the same pipeline, run in place.
        photosRepositoryProvider.overrideWith(
          (ref) => PhotosRepository(
            ref.watch(appDatabaseProvider),
            ref.watch(hlcClockProvider),
            ref.watch(idGeneratorProvider),
            ref.watch(photoStoreProvider),
            process: (raw) async => processPhoto(raw),
          ),
        ),
      ],
      seed: (db, inbox) => db.upsertList(
        TaskList(
          id: 'work',
          name: 'Work',
          sortKey: SortKey.after(inbox.sortKey),
          updatedAt: testClock('a').now().toString(),
        ),
      ),
    );
    final result = showAppSheet<bool>(
      context: app.router.routerDelegate.navigatorKey.currentContext!,
      isScrollControlled: true,
      builder: (_) => ShareTaskSheet(draft: draft),
    );
    await tester.pumpAndSettle();
    return (app, result);
  }

  Future<List<Task>> liveTasks(AppDatabase db) =>
      (db.select(db.tasks)..where((t) => t.deletedAt.isNull())).get();

  appTest('opens prefilled from the draft', (tester) async {
    await openSheet(
      tester,
      const ShareDraft(title: 'Read this', notes: 'https://example.com'),
    );

    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Read this'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('share-list')),
        matching: find.text('Inbox'),
      ),
      findsOneWidget,
    );
  });

  appTest('save reads the title as quick add and files it in the Inbox', (
    tester,
  ) async {
    final (app, result) = await openSheet(
      tester,
      const ShareDraft(title: 'Pasta recipe', notes: 'From Anna'),
    );

    await tester.enterText(
      find.byKey(const Key('share-title')),
      'Pasta recipe #food !high tomorrow',
    );
    await tester.tap(find.byKey(const Key('share-save')));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    final tasks = await liveTasks(app.db);
    expect(tasks, hasLength(1));
    final task = tasks.single;
    expect(task.title, 'Pasta recipe');
    expect(task.tags, ['food']);
    expect(task.priority, 3);
    expect(task.dueAt, dayStartMsFrom(testNow, 1));
    expect(task.notes, 'From Anna');
    expect(task.listId, app.inbox.id);
    expect(find.text('Added to Inbox'), findsOneWidget);
  });

  appTest('a picked list is the one it goes to', (tester) async {
    final (app, _) = await openSheet(
      tester,
      const ShareDraft(title: 'Expense report'),
    );

    await tester.tap(find.byKey(const Key('share-list')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-save')));
    await tester.pumpAndSettle();

    expect((await liveTasks(app.db)).single.listId, 'work');
    expect(find.text('Added to Work'), findsOneWidget);
  });

  appTest('cancel writes nothing', (tester) async {
    final (app, result) = await openSheet(
      tester,
      ShareDraft(title: 'Nope', images: [smallJpeg()]),
    );

    await tester.tap(find.byKey(const Key('share-cancel')));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(await liveTasks(app.db), isEmpty);
    expect(await app.db.select(app.db.photos).get(), isEmpty);
    expect(find.byKey(const Key('share-sheet')), findsNothing);
  });

  appTest('save stays off while the title is empty', (tester) async {
    await openSheet(tester, ShareDraft(images: [smallJpeg()]));

    FilledButton save() =>
        tester.widget<FilledButton>(find.byKey(const Key('share-save')));
    expect(save().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('share-title')), 'Receipt');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  appTest('pictures go through the photo pipeline onto the task', (
    tester,
  ) async {
    final shared = smallJpeg(width: 40, height: 30);
    final (app, _) = await openSheet(
      tester,
      ShareDraft(title: 'Receipt', images: [shared, smallJpeg()]),
    );
    expect(find.byKey(const Key('share-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('share-photo-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('share-save')));
    await tester.pumpAndSettle();

    final task = (await liveTasks(app.db)).single;
    final photos = await app.db.photosOfParent(PhotoParent.task, task.id);
    expect(photos, hasLength(2));
    // Re-encoded on the way in, exactly as the camera's are: what is
    // stored is the pipeline's output, not the bytes that were shared.
    final processed = processPhoto(shared)!;
    expect(photos.first.sha256, processed.sha256);
    expect((photos.first.width, photos.first.height), (40, 30));
    final stored = await app.container
        .read(photoStoreProvider)
        .get(photos.first.sha256);
    expect(stored, processed.bytes);
    expect(stored, isNot(shared));
  });

  appTest('a left-out picture is not attached', (tester) async {
    final (app, _) = await openSheet(
      tester,
      ShareDraft(title: 'Two', images: [smallJpeg(), smallJpeg(width: 8)]),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('share-photo-0')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share-photo-1')), findsNothing);
    await tester.tap(find.byKey(const Key('share-save')));
    await tester.pumpAndSettle();

    final task = (await liveTasks(app.db)).single;
    final photos = await app.db.photosOfParent(PhotoParent.task, task.id);
    expect(photos.single.width, 8);
  });

  appTest('bytes that are not a picture are skipped and said so', (
    tester,
  ) async {
    final (app, _) = await openSheet(
      tester,
      ShareDraft(
        title: 'Mixed',
        images: [
          Uint8List.fromList([1, 2, 3, 4]),
          smallJpeg(),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('share-save')));
    await tester.pumpAndSettle();

    final task = (await liveTasks(app.db)).single;
    expect(
      await app.db.photosOfParent(PhotoParent.task, task.id),
      hasLength(1),
    );
    // The confirmation first, then the complaint.
    expect(find.text('Added to Inbox'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('That file is not a picture.'), findsOneWidget);
  });
}
