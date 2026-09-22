import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/note_body_view.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo/l10n/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, String body, List<Object> overrides) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp(
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: Scaffold(body: NoteBodyView(body: body)),
          ),
        ),
      );

  /// Fires the tap gesture recognizer flutter_markdown_plus attaches to a
  /// link's `TextSpan`, the way the package's own link tests do.
  ///
  /// `NoteBodyView` renders with `selectable: true`, so the body is a
  /// `SelectableText`, not a `Text`: `tester.tap` on the rendered characters
  /// does not reach the span's recognizer, there is no separate
  /// hit-testable widget at that offset for it to hit.
  void tapLink(WidgetTester tester) {
    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    TapGestureRecognizer? recognizer;
    selectable.textSpan!.visitChildren((span) {
      if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
        recognizer = span.recognizer! as TapGestureRecognizer;
      }
      return true;
    });
    recognizer!.onTap!();
  }

  testWidgets('tapping an https link opens exactly that URL', (tester) async {
    final opened = <Uri>[];
    await pump(tester, '[docs](https://example.com/docs)', [
      openUrlProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ]);

    tapLink(tester);

    expect(opened, [Uri.parse('https://example.com/docs')]);
  });

  testWidgets('tapping a non-web scheme link opens nothing', (tester) async {
    final opened = <Uri>[];
    await pump(tester, '[run me](javascript:alert(1))', [
      openUrlProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ]);

    tapLink(tester);

    expect(opened, isEmpty);
  });

  testWidgets('an empty body shows a dimmed hint, not a blank area', (
    tester,
  ) async {
    await pump(tester, '', []);

    final l = L.of(tester.element(find.byType(NoteBodyView)));
    expect(find.text(l.notePreviewEmpty), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('a body that is only whitespace also shows the hint', (
    tester,
  ) async {
    await pump(tester, '   \n  ', []);

    final l = L.of(tester.element(find.byType(NoteBodyView)));
    expect(find.text(l.notePreviewEmpty), findsOneWidget);
  });
}
