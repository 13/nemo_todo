import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';
import 'package:nemo/features/notes/ui/markdown/read_lines.dart';

void main() {
  group('stripMarkdown', () {
    test('drops inline markers and link targets', () {
      expect(
        stripMarkdown(
          '**500 g** _flour_ ~~no~~ `x` [recipe](https://a.io/b_c)',
        ),
        '500 g flour no x recipe',
      );
    });

    test('drops a heading marker', () {
      expect(stripMarkdown('## Dough'), 'Dough');
    });
  });

  group('readLines', () {
    test('classifies each line and keeps source offsets', () {
      const body =
          '# Title\ntext\n- [x] done\n- [ ] open\n- bullet\n'
          '2. second\n> quoted\n---\n\n```\ncode\n```';
      final lines = readLines(body);
      expect(lines.map((l) => l.kind), [
        ReadKind.heading,
        ReadKind.text,
        ReadKind.task,
        ReadKind.task,
        ReadKind.bullet,
        ReadKind.numbered,
        ReadKind.quote,
        ReadKind.rule,
        ReadKind.blank,
        ReadKind.codeBlock,
      ]);
      final heading = lines[0];
      expect(heading.level, 1);
      expect(body.substring(heading.contentStart, heading.end), 'Title');
      expect(lines[2].checked, isTrue);
      expect(lines[3].checked, isFalse);
      expect(body.substring(lines[3].contentStart, lines[3].end), 'open');
      expect(lines[5].marker, '2.');
      expect(body.substring(lines[6].contentStart, lines[6].end), 'quoted');
      final code = lines.last;
      // A closed block's `end` runs through the closing fence -- callers
      // that want to render just the code strip the trailing fence line
      // themselves (see task 4's `note_read_view.dart`).
      expect(body.substring(code.contentStart, code.end), 'code\n```');
      expect(code.end, body.length);
    });

    test('an unclosed fence runs to the end of the body', () {
      final lines = readLines('a\n```\nx\ny');
      expect(lines.last.kind, ReadKind.codeBlock);
      expect('a\n```\nx\ny'.substring(lines.last.contentStart), 'x\ny');
    });

    test('indent is kept as level on list lines', () {
      final lines = readLines('  - nested');
      expect(lines.single.kind, ReadKind.bullet);
      expect(lines.single.level, 2);
    });
  });

  group('toggleTaskAt', () {
    test('ticks an open box and unticks a ticked one', () {
      const body = 'a\n- [ ] milk\n- [X] eggs';
      final ticked = toggleTaskAt(body, 2);
      expect(ticked, 'a\n- [x] milk\n- [X] eggs');
      // The second task line starts at 13 (`readLines`' own convention for
      // `ReadLine.start`), not 12, which is still the first line's `\n`.
      expect(toggleTaskAt(ticked, 13), 'a\n- [x] milk\n- [ ] eggs');
    });

    test('leaves a non-task line alone', () {
      expect(toggleTaskAt('plain', 0), 'plain');
    });
  });
}
