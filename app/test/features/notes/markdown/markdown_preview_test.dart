import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_preview.dart';

void main() {
  // A bare `ThemeData()` leaves its heading sizes null -- they are only
  // filled in from locale geometry when resolved through `Theme.of` in a
  // widget tree, which these plain `test()` blocks have none of. Supplying
  // the English geometry here gives the heading test real numbers to
  // compare against, the way every real caller's theme already has.
  final theme = ThemeData(textTheme: Typography.material2021().englishLike);
  const base = TextStyle(fontSize: 14);

  test('a web link gets the recogniser for its URL', () {
    final urls = <String>[];
    final span = markdownSpan(
      'see [shop](https://a.io/x_(y)) now',
      base,
      theme,
      linkRecognizer: (url) {
        urls.add(url);
        return TapGestureRecognizer();
      },
    );
    expect(span.toPlainText(), 'see shop now');
    expect(urls, ['https://a.io/x_(y)']);
    final link = span.children!.cast<TextSpan>().firstWhere(
      (s) => s.text == 'shop',
    );
    expect(link.recognizer, isA<TapGestureRecognizer>());
  });

  test('a task link becomes the chip in place of its text', () {
    final span = markdownSpan(
      'milk [→ task](nemo://task/t1)',
      base,
      theme,
      taskChip: (id) => Text('chip $id'),
    );
    final chip = span.children!.whereType<WidgetSpan>().single;
    expect((chip.child as Text).data, 'chip t1');
    expect(
      span.children!.whereType<TextSpan>().map((s) => s.text).join(),
      'milk ',
    );
  });

  test('headings are full size unless capped', () {
    TextStyle? size({required bool cap}) => markdownSpan(
      '# Big',
      base,
      theme,
      capHeadings: cap,
    ).children!.cast<TextSpan>().single.style;
    expect(size(cap: false)!.fontSize, theme.textTheme.headlineSmall!.fontSize);
    expect(size(cap: true)!.fontSize, closeTo(14 * 1.2, 0.01));
  });
}
