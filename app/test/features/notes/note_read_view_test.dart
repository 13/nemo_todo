import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/note_read_view.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String body,
  ValueChanged<String>? onChanged,
  ValueChanged<int>? onEditAt,
  void Function(int, Offset)? onLongPress,
  ValueChanged<String>? onOpenLink,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: NoteReadView(
        body: body,
        onChanged: onChanged ?? (_) {},
        onEditAt: onEditAt ?? (_) {},
        onLongPressLine: onLongPress ?? (_, _) {},
        onOpenLink: onOpenLink ?? (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('shows markdown with its markers hidden', (tester) async {
    await _pump(
      tester,
      body: '# Dough\n**500 g** flour\n- salt\n```\nknead\n```',
    );
    expect(find.text('Dough'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(
      find.textContaining('500 g flour', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('•', findRichText: true), findsOneWidget);
    expect(find.textContaining('knead', findRichText: true), findsOneWidget);
    expect(find.textContaining('```', findRichText: true), findsNothing);
  });

  testWidgets('tapping a checkbox writes the flipped body', (tester) async {
    String? written;
    await _pump(
      tester,
      body: 'list\n- [ ] milk',
      onChanged: (b) => written = b,
    );
    await tester.tap(find.byKey(const Key('read-check-1')));
    expect(written, 'list\n- [x] milk');
  });

  testWidgets('tapping text asks to edit at that line', (tester) async {
    int? at;
    await _pump(tester, body: 'one\ntwo', onEditAt: (o) => at = o);
    await tester.tap(find.byKey(const Key('read-line-1')));
    expect(at, 4);
  });

  testWidgets('long-press reports the line', (tester) async {
    int? at;
    await _pump(tester, body: 'one\n- [ ] two', onLongPress: (o, _) => at = o);
    await tester.longPress(find.byKey(const Key('read-line-1')));
    expect(at, 4);
  });

  testWidgets('tapping a web link opens it instead of editing', (tester) async {
    String? opened;
    int? at;
    await _pump(
      tester,
      body: '[shop](https://a.io)',
      onOpenLink: (u) => opened = u,
      onEditAt: (o) => at = o,
    );
    await tester.tapOnText(find.textRange.ofSubstring('shop'));
    expect(opened, 'https://a.io');
    expect(at, isNull);
  });

  testWidgets('an empty code block shows no fence', (tester) async {
    await _pump(tester, body: '```\n```');
    expect(find.textContaining('```', findRichText: true), findsNothing);
  });
}
