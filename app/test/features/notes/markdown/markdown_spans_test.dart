import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';

/// Every style covering the character at [index] of [text].
Set<MdStyle> stylesAt(String text, int index) => {
  for (final r in parseMarkdownRanges(text))
    if (r.start <= index && index < r.end) r.style,
};

/// Styles at the first occurrence of [needle] in [text].
Set<MdStyle> stylesOf(String text, String needle) =>
    stylesAt(text, text.indexOf(needle));

void main() {
  group('headings', () {
    for (var level = 1; level <= 6; level++) {
      test('level $level styles the line and marks the hashes', () {
        final text = '${'#' * level} Title';
        final heading = MdStyle.values[level - 1];
        expect(stylesOf(text, 'Title'), {heading});
        expect(stylesAt(text, 0), {heading, MdStyle.marker});
      });
    }

    test('hashes without a space are plain text', () {
      expect(parseMarkdownRanges('#hashtag'), isEmpty);
    });
  });

  group('emphasis', () {
    test('bold with both spellings', () {
      expect(stylesOf('a **b** c', 'b'), {MdStyle.bold});
      expect(stylesOf('a __b__ c', 'b'), {MdStyle.bold});
      expect(stylesAt('a **b** c', 2), {MdStyle.marker});
    });

    test('italic with both spellings', () {
      expect(stylesOf('a *b* c', 'b'), {MdStyle.italic});
      expect(stylesOf('a _b_ c', 'b'), {MdStyle.italic});
      expect(stylesAt('a _b_ c', 2), {MdStyle.marker});
    });

    test('strike', () {
      expect(stylesOf('~~gone~~', 'gone'), {MdStyle.strike});
      expect(stylesAt('~~gone~~', 0), {MdStyle.marker});
    });

    test('italic nested one level inside bold', () {
      const text = '**bold *and italic***';
      expect(stylesOf(text, 'bold'), {MdStyle.bold});
      expect(stylesOf(text, 'and'), {MdStyle.bold, MdStyle.italic});
    });

    test('an unclosed delimiter stays plain', () {
      expect(parseMarkdownRanges('**never closed'), isEmpty);
      expect(parseMarkdownRanges('~~never closed'), isEmpty);
    });

    test('an underscore inside a word is not emphasis', () {
      expect(parseMarkdownRanges('snake_case_name'), isEmpty);
    });

    test('no inline span crosses a newline', () {
      expect(parseMarkdownRanges('**a\nb**'), isEmpty);
    });
  });

  group('inline code', () {
    test('is code and shields its contents', () {
      const text = 'run `a **b** c` now';
      expect(stylesOf(text, 'b'), {MdStyle.code});
      expect(stylesOf(text, 'now'), isEmpty);
    });
  });

  group('links', () {
    test('text is link, brackets and url are markers', () {
      const text = 'see [docs](https://x.y/a_b_c) ok';
      expect(stylesOf(text, 'docs'), {MdStyle.link});
      expect(stylesOf(text, '['), {MdStyle.marker});
      expect(stylesOf(text, 'https'), {MdStyle.marker});
      // Underscores in the URL are not italic.
      expect(stylesOf(text, 'b_c'), {MdStyle.marker});
      expect(stylesOf(text, 'ok'), isEmpty);
    });

    test('a URL with balanced parentheses is marked whole', () {
      const text = '[w](https://en.wikipedia.org/wiki/Foo_(bar)) ok';
      final close = text.indexOf(' ok') - 1;
      expect(stylesAt(text, close), {MdStyle.marker});
      expect(stylesOf(text, 'bar'), {MdStyle.marker});
      expect(stylesOf(text, 'ok'), isEmpty);
      expect(
        parseMarkdownRanges(text),
        contains(MdRange(2, close + 1, MdStyle.marker)),
      );
    });
  });

  group('blocks', () {
    test('quote styles the line and marks the >', () {
      expect(stylesOf('> said', 'said'), {MdStyle.quote});
      expect(stylesAt('> said', 0), {MdStyle.quote, MdStyle.marker});
    });

    test('bullets and numbers are list markers', () {
      expect(stylesAt('- milk', 0), {MdStyle.listMarker});
      expect(stylesAt('* milk', 0), {MdStyle.listMarker});
      expect(stylesAt('+ milk', 0), {MdStyle.listMarker});
      expect(stylesAt('12. milk', 1), {MdStyle.listMarker});
      expect(stylesOf('- milk', 'milk'), isEmpty);
    });

    test('an open task is a list marker, a checked one is done', () {
      expect(stylesOf('- [ ] bread', '['), {MdStyle.listMarker});
      expect(stylesOf('- [ ] bread', 'bread'), isEmpty);
      expect(stylesOf('- [x] bread', 'bread'), {MdStyle.taskDone});
      expect(stylesOf('- [X] bread', 'bread'), {MdStyle.taskDone});
    });

    test('a bare task box with nothing after it is a task marker', () {
      expect(parseMarkdownRanges('- [x]'), [
        const MdRange(0, 5, MdStyle.listMarker),
      ]);
      expect(parseMarkdownRanges('- [ ]'), [
        const MdRange(0, 5, MdStyle.listMarker),
      ]);
    });

    test('inline styles work inside list items', () {
      expect(stylesOf('- **milk**', 'milk'), {MdStyle.bold});
    });

    test('a horizontal rule is a marker', () {
      expect(stylesAt('---', 1), {MdStyle.marker});
      expect(stylesAt('* * *', 2), {MdStyle.marker});
    });

    test('a fenced block is code, with no inline parsing inside', () {
      const text = 'a\n```\n**x**\n```\nb';
      expect(stylesOf(text, '**x'), {MdStyle.codeBlock});
      expect(stylesOf(text, '```'), {MdStyle.codeBlock});
      expect(stylesOf(text, 'b'), isEmpty);
    });

    test('an unclosed fence runs to the end', () {
      const text = '```\n**x**';
      expect(stylesAt(text, text.length - 1), {MdStyle.codeBlock});
    });
  });

  test('offsets are UTF-16 and stay right after emoji and umlauts', () {
    const text = '🍞 Brötchen **süß**';
    expect(stylesOf(text, 'süß'), {MdStyle.bold});
    expect(stylesAt(text, text.length - 1), {MdStyle.marker});
    expect(stylesOf(text, 'Brötchen'), isEmpty);
  });

  test('empty text has no ranges', () {
    expect(parseMarkdownRanges(''), isEmpty);
  });
}
