import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_commands.dart';

/// Builds a value from text where `|` marks a collapsed cursor, or `[`
/// and `]` mark a selection. The markers are not part of the text.
TextEditingValue v(String marked) {
  final caret = marked.indexOf('|');
  if (caret >= 0) {
    return TextEditingValue(
      text: marked.replaceFirst('|', ''),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
  final start = marked.indexOf('[');
  final end = marked.indexOf(']') - 1;
  return TextEditingValue(
    text: marked.replaceFirst('[', '').replaceFirst(']', ''),
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );
}

/// The inverse of [v], for readable expectations.
String show(TextEditingValue value) {
  final s = value.selection;
  if (s.isCollapsed) {
    return value.text.replaceRange(s.start, s.start, '|');
  }
  return value.text
      .replaceRange(s.end, s.end, ']')
      .replaceRange(s.start, s.start, '[');
}

void main() {
  group('toggleInline', () {
    test('wraps a selection', () {
      expect(
        show(toggleInline(v('buy [milk] now'), '**')),
        'buy **[milk]** now',
      );
    });

    test('unwraps when the markers sit just outside', () {
      expect(
        show(toggleInline(v('buy **[milk]** now'), '**')),
        'buy [milk] now',
      );
    });

    test('unwraps when the markers are inside the selection', () {
      expect(
        show(toggleInline(v('buy [**milk**] now'), '**')),
        'buy [milk] now',
      );
    });

    test('a collapsed cursor inserts a pair and sits between', () {
      expect(show(toggleInline(v('a |b'), '~~')), 'a ~~|~~b');
    });

    test('a second toggle on an empty pair removes it', () {
      expect(show(toggleInline(v('a ~~|~~b'), '~~')), 'a |b');
    });

    test('surrounding spaces stay outside the markers', () {
      expect(show(toggleInline(v('a[ milk ]b'), '_')), 'a _[milk]_ b');
    });

    test('an invalid selection appends at the end', () {
      final value = toggleInline(const TextEditingValue(text: 'ab'), '`');
      expect(show(value), 'ab`|`');
    });
  });

  group('toggleLinePrefix', () {
    test('adds a bullet to the cursor line', () {
      expect(show(toggleLinePrefix(v('one\ntw|o'), '- ')), 'one\n- tw|o');
    });

    test('removes it when present', () {
      expect(show(toggleLinePrefix(v('- tw|o'), '- ')), 'tw|o');
    });

    test('prefixes every touched line, skipping blank ones', () {
      expect(show(toggleLinePrefix(v('[a\n\nb]'), '> ')), '[> a\n\n> b]');
    });

    test('mixed lines get the prefix added, not toggled per line', () {
      expect(show(toggleLinePrefix(v('[- a\nb]'), '- ')), '[- a\n- b]');
    });

    test('numbers count up', () {
      expect(
        show(toggleLinePrefix(v('[a\nb\nc]'), '1. ')),
        '[1. a\n2. b\n3. c]',
      );
    });

    test('numbered lines lose their numbers', () {
      expect(show(toggleLinePrefix(v('[1. a\n2. b]'), '1. ')), '[a\nb]');
    });

    test('switching kind replaces the old prefix', () {
      expect(show(toggleLinePrefix(v('- a|'), '1. ')), '1. a|');
    });
  });

  group('cycleHeading', () {
    test('none, #, ##, ###, none', () {
      var value = v('Tit|le');
      value = cycleHeading(value);
      expect(show(value), '# Tit|le');
      value = cycleHeading(value);
      expect(show(value), '## Tit|le');
      value = cycleHeading(value);
      expect(show(value), '### Tit|le');
      value = cycleHeading(value);
      expect(show(value), 'Tit|le');
    });

    test('only the cursor line changes', () {
      expect(show(cycleHeading(v('a\nb|\nc'))), 'a\n# b|\nc');
    });
  });

  group('toggleCheckbox', () {
    test('flips an open box', () {
      expect(show(toggleCheckbox(v('- [ ] br|ead'))), '- [x] br|ead');
    });

    test('flips a bare open box with nothing after it', () {
      expect(show(toggleCheckbox(v('- [ ]|'))), '- [x]|');
    });

    test('flips a bare checked box with nothing after it back', () {
      expect(show(toggleCheckbox(v('- [x]|'))), '- [ ]|');
    });

    test('flips a checked box back', () {
      expect(show(toggleCheckbox(v('- [X] br|ead'))), '- [ ] br|ead');
    });

    test('promotes a bullet', () {
      expect(show(toggleCheckbox(v('- br|ead'))), '- [ ] br|ead');
    });

    test('prefixes a plain line', () {
      expect(show(toggleCheckbox(v('br|ead'))), '- [ ] br|ead');
    });
  });

  group('toggleCodeBlock', () {
    test('wraps the touched lines in fences', () {
      expect(show(toggleCodeBlock(v('[a\nb]'))), '```\n[a\nb]\n```');
    });

    test('an empty line becomes an empty block with the cursor inside', () {
      expect(show(toggleCodeBlock(v('|'))), '```\n|\n```');
    });

    test('inside a block, removes its fences', () {
      expect(show(toggleCodeBlock(v('x\n```\nco|de\n```\ny'))), 'x\nco|de\ny');
    });
  });

  group('insertLink', () {
    test('wraps the selection', () {
      expect(
        show(insertLink(v('see [docs] now'), 'https://x.y')),
        'see [docs](https://x.y)| now',
      );
    });

    test('with no selection uses the url as text', () {
      expect(
        show(insertLink(v('|'), 'https://x.y')),
        '[https://x.y](https://x.y)|',
      );
    });
  });

  group('continueList', () {
    test('continues a bullet', () {
      expect(show(continueList(v('- milk|'))!), '- milk\n- |');
    });

    test('increments a number', () {
      expect(show(continueList(v('9. milk|'))!), '9. milk\n10. |');
    });

    test('continues a task unchecked, keeping indent', () {
      expect(
        show(continueList(v('  - [x] milk|'))!),
        '  - [x] milk\n  - [ ] |',
      );
    });

    test('splits a line at the cursor', () {
      expect(show(continueList(v('- mi|lk'))!), '- mi\n- |lk');
    });

    test('an empty item ends the list', () {
      expect(show(continueList(v('- a\n- |'))!), '- a\n|');
    });

    test('a plain line is not a list', () {
      expect(continueList(v('milk|')), isNull);
    });

    test('a cursor inside the prefix is not a continuation', () {
      expect(continueList(v('-| milk')), isNull);
    });
  });

  group('linkAtCursor', () {
    const text = 'a [b](https://x.y) c';
    TextEditingValue at(int offset) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );

    test('inside a link', () {
      expect(linkAtCursor(at(text.indexOf('b'))), 'https://x.y');
    });

    test('on either edge of a link', () {
      expect(linkAtCursor(at(text.indexOf('['))), 'https://x.y');
      expect(linkAtCursor(at(text.indexOf(')') + 1)), 'https://x.y');
    });

    test('keeps balanced parentheses in the URL', () {
      const wiki = '[w](https://en.wikipedia.org/wiki/Foo_(bar)) c';
      expect(
        linkAtCursor(
          const TextEditingValue(
            text: wiki,
            selection: TextSelection.collapsed(offset: 1),
          ),
        ),
        'https://en.wikipedia.org/wiki/Foo_(bar)',
      );
    });

    test('outside a link', () {
      expect(linkAtCursor(at(0)), isNull);
      expect(linkAtCursor(at(text.length)), isNull);
    });
  });

  group('ListContinuationFormatter', () {
    final formatter = ListContinuationFormatter();

    test('turns a typed newline on a list line into a continuation', () {
      final result = formatter.formatEditUpdate(v('- milk|'), v('- milk\n|'));
      expect(show(result), '- milk\n- |');
    });

    test('leaves other edits alone', () {
      final typed = v('- milkx|');
      expect(formatter.formatEditUpdate(v('- milk|'), typed), typed);
      final pasted = v('- milk\nbread|');
      expect(formatter.formatEditUpdate(v('- milk|'), pasted), pasted);
    });

    test('leaves a newline on a plain line alone', () {
      final next = v('milk\n|');
      expect(formatter.formatEditUpdate(v('milk|'), next), next);
    });
  });
}
