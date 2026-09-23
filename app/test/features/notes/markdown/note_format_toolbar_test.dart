import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo/l10n/app_localizations.dart';

void main() {
  late MarkdownEditingController controller;
  late UndoHistoryController undo;
  late FocusNode focus;
  late List<Uri> opened;

  Future<void> pump(WidgetTester tester, TextEditingValue value) async {
    controller = MarkdownEditingController()..value = value;
    undo = UndoHistoryController();
    focus = FocusNode();
    opened = [];
    addTearDown(controller.dispose);
    addTearDown(undo.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openUrlProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            // A `Builder` so `onInsertLink` below closes over this
            // subtree's own context, the way `NoteDetailScreen` closes
            // over its own stable context -- not the outer `MaterialApp`
            // context `pumpWidget` itself would otherwise hand this
            // function.
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextField(
                    controller: controller,
                    undoController: undo,
                    focusNode: focus,
                  ),
                  NoteFormatToolbar(
                    controller: controller,
                    undoController: undo,
                    onInsertLink: () => unawaited(
                      promptForLink(context, controller, focusNode: focus),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextEditingValue sel(String text, int start, int end) => TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );

  TextEditingValue at(String text, int offset) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: offset),
  );

  final cases = <String, (TextEditingValue, String)>{
    'md-bold': (sel('milk', 0, 4), '**milk**'),
    'md-italic': (sel('milk', 0, 4), '_milk_'),
    'md-strike': (sel('milk', 0, 4), '~~milk~~'),
    'md-code': (sel('milk', 0, 4), '`milk`'),
    'md-heading': (at('milk', 0), '# milk'),
    'md-bullet': (at('milk', 0), '- milk'),
    'md-numbered': (at('milk', 0), '1. milk'),
    'md-checkbox': (at('milk', 0), '- [ ] milk'),
    'md-quote': (at('milk', 0), '> milk'),
    'md-code-block': (at('milk', 0), '```\nmilk\n```'),
  };
  for (final MapEntry(:key, value: (start, expected)) in cases.entries) {
    testWidgets('$key edits the text', (tester) async {
      await pump(tester, start);
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(controller.text, expected);
    });
  }

  testWidgets('link asks for a URL and wraps the selection', (tester) async {
    await pump(tester, sel('docs', 0, 4));
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('md-link-url')), 'https://x.y');
    await tester.tap(find.byKey(const Key('md-link-ok')));
    await tester.pumpAndSettle();
    expect(controller.text, '[docs](https://x.y)');
  });

  testWidgets('cancelling the link dialog changes nothing', (tester) async {
    await pump(tester, sel('docs', 0, 4));
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('md-link-cancel')));
    await tester.pumpAndSettle();
    expect(controller.text, 'docs');
  });

  testWidgets('cancelling the link dialog gives focus back to the body', (
    tester,
  ) async {
    await pump(tester, sel('docs', 0, 4));
    focus.requestFocus();
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);

    await tester.tap(find.byKey(const Key('md-link-cancel')));
    await tester.pumpAndSettle();

    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'docs');
  });

  testWidgets('the link dialog refocuses the body on cancel even when the '
      'route would not restore it', (tester) async {
    // Nothing was focused when the dialog opened, so the dialog route's
    // own focus restoration has nothing to hand back. Only
    // `promptForLink` itself can put the cursor back in the body.
    await pump(tester, sel('docs', 0, 4));
    expect(focus.hasFocus, isFalse);
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('md-link-cancel')));
    await tester.pumpAndSettle();

    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'docs');
  });

  testWidgets('an empty link URL gives focus back to the body too', (
    tester,
  ) async {
    await pump(tester, sel('docs', 0, 4));
    focus.requestFocus();
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('md-link-url')), '   ');
    await tester.tap(find.byKey(const Key('md-link-ok')));
    await tester.pumpAndSettle();

    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'docs');
  });

  testWidgets('open link shows only in a web link and opens it', (
    tester,
  ) async {
    const text = '[a](https://x.y) [b](javascript:alert(1))';
    // End of text touches the javascript link, which must not qualify.
    await pump(tester, at(text, text.length));
    expect(find.byKey(const Key('md-open-link')), findsNothing);

    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-open-link')));
    expect(opened, [Uri.parse('https://x.y')]);

    controller.selection = TextSelection.collapsed(offset: text.indexOf('b]'));
    await tester.pump();
    expect(find.byKey(const Key('md-open-link')), findsNothing);
  });

  test('isWebLink', () {
    expect(isWebLink('https://x.y'), isTrue);
    expect(isWebLink('http://x.y'), isTrue);
    expect(isWebLink('javascript:alert(1)'), isFalse);
    expect(isWebLink('file:///etc/passwd'), isFalse);
    expect(isWebLink('mailto:a@b.c'), isFalse);
  });
}
