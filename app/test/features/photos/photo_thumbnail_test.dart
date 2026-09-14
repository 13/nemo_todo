import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

import '../../support/test_db.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Future<void> pump(WidgetTester tester, List<Object> overrides) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => testNow),
          photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
          ...overrides.cast(),
        ],
        child: const MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: PhotoThumbnail(sha256: hash, size: 72)),
        ),
      ),
    );
  }

  testWidgets('shows the placeholder glyph, never a spinner, while bytes '
      'are unavailable', (tester) async {
    await pump(tester, const []);
    await tester.pump();

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'shows the placeholder glyph, never an error widget, when the bytes '
    'provider fails',
    (tester) async {
      await pump(tester, [
        photoBytesProvider(hash)
            .overrideWith((ref) => Future<Uint8List?>.error(Exception('boom'))),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
