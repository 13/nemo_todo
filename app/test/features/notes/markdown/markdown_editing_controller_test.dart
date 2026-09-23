import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';

void main() {
  Future<TextSpan> build(
    WidgetTester tester,
    MarkdownEditingController controller, {
    bool withComposing = false,
  }) async {
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 14),
              withComposing: withComposing,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return span;
  }

  List<TextSpan> leaves(TextSpan root) {
    final out = <TextSpan>[];
    root.visitChildren((s) {
      if (s is TextSpan && s.text != null) out.add(s);
      return true;
    });
    return out;
  }

  TextSpan leafWith(TextSpan root, String text) =>
      leaves(root).firstWhere((s) => s.text == text);

  testWidgets('painted text is exactly the stored text', (tester) async {
    const body = '# Title\n- [x] **done** ~~old~~ `c`\n> q [l](https://x.y)';
    final span = await build(tester, MarkdownEditingController(text: body));
    expect(span.toPlainText(), body);
  });

  testWidgets('bold is bold and its markers are faint', (tester) async {
    final span = await build(
      tester,
      MarkdownEditingController(text: 'a **b** c'),
    );
    expect(leafWith(span, 'b').style!.fontWeight, FontWeight.w700);
    final marker = leafWith(span, '**').style!.color!;
    expect(marker.a, lessThan(1));
  });

  testWidgets('strike and done tasks are struck through', (tester) async {
    final span = await build(
      tester,
      MarkdownEditingController(text: '~~a~~\n- [x] b'),
    );
    expect(
      leafWith(
        span,
        'a',
      ).style!.decoration!.contains(TextDecoration.lineThrough),
      isTrue,
    );
    expect(
      leafWith(
        span,
        'b',
      ).style!.decoration!.contains(TextDecoration.lineThrough),
      isTrue,
    );
  });

  testWidgets('a heading is larger than body text', (tester) async {
    final span = await build(tester, MarkdownEditingController(text: '# Big'));
    expect(leafWith(span, 'Big').style!.fontSize, greaterThan(14));
  });

  testWidgets('the composing range is underlined on top of the style', (
    tester,
  ) async {
    final controller = MarkdownEditingController(text: '**ab**')
      ..value = const TextEditingValue(
        text: '**ab**',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      );
    final span = await build(tester, controller, withComposing: true);
    final style = leafWith(span, 'ab').style!;
    expect(style.fontWeight, FontWeight.w700);
    expect(style.decoration!.contains(TextDecoration.underline), isTrue);
  });

  testWidgets('empty text builds an empty span', (tester) async {
    final span = await build(tester, MarkdownEditingController());
    expect(span.toPlainText(), '');
  });

  test('marker wins over other colours', () {
    final theme = ThemeData();
    final style = markdownStyle(
      {MdStyle.link, MdStyle.marker},
      const TextStyle(),
      theme,
    );
    expect(style.color, isNot(theme.colorScheme.primary));
  });
}
