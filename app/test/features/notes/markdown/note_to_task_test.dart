import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';

TextEditingValue _sel(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

void main() {
  test('plainLine strips list, task, heading and inline markdown', () {
    expect(plainLine('- [ ] buy **milk**'), 'buy milk');
    expect(plainLine('  * see [shop](https://a.io)'), 'see shop');
    expect(plainLine('3. call _Bob_'), 'call Bob');
    expect(plainLine('## Plan'), 'Plan');
    expect(plainLine('- x [→ task](nemo://task/t1)'), 'x');
  });

  group('todoCandidates', () {
    test('a selection within a line anchors at the selection end', () {
      const text = 'call Bob tomorrow';
      final c = todoCandidates(_sel(text, 0, 8)).single;
      expect(c.title, 'call Bob');
      expect(c.anchor, 8);
    });

    test('a multi-line selection gives one per line, skipping blank, '
        'ticked and linked lines', () {
      const text =
          '- [ ] milk\n\n- [x] eggs\n- bread\n'
          '- jam [→ task](nemo://task/t1)\nflour';
      final cs = todoCandidates(_sel(text, 2, text.length));
      expect(cs.map((c) => c.title), ['milk', 'bread', 'flour']);
      expect(cs.first.anchor, 10);
      expect(cs.last.anchor, text.length);
    });

    test('a cursor on a list line takes that line', () {
      const text = 'intro\n- [ ] milk';
      final c = todoCandidates(_sel(text, 9)).single;
      expect(c.title, 'milk');
      expect(c.anchor, text.length);
    });

    test('a selection ending at the start of the next line leaves that '
        'line out', () {
      expect(todoCandidates(_sel('a\nb', 0, 2)).map((c) => c.title), ['a']);
      const text = 'one\ntwo\nthree';
      expect(todoCandidates(_sel(text, 0, 8)).map((c) => c.title), [
        'one',
        'two',
      ]);
    });

    test('a cursor on plain text gives nothing', () {
      expect(todoCandidates(_sel('just words', 3)), isEmpty);
    });

    test('a selection on an already-linked line gives nothing', () {
      const text = 'call Bob [→ task](nemo://task/t1) today';
      expect(todoCandidates(_sel(text, 0, 4)), isEmpty);
    });
  });

  test('lineCandidate takes any non-empty unlinked line', () {
    const body = 'first\n- [x] done';
    expect(lineCandidate(body, 6)!.title, 'done');
    expect(lineCandidate(body, 6)!.anchor, body.length);
    expect(lineCandidate('a [→ task](nemo://task/t1)', 0), isNull);
    expect(lineCandidate('\n', 0), isNull);
  });

  test("linkedTaskAt finds a task link on the offset's line", () {
    const body = 'a\n- milk [→ task](nemo://task/t-1)\nb';
    expect(linkedTaskAt(body, 4), 't-1');
    expect(linkedTaskAt(body, 0), isNull);
  });

  test('taskIdFromLink reads nemo task links only', () {
    expect(taskIdFromLink('nemo://task/abc-1'), 'abc-1');
    expect(taskIdFromLink('https://a.io'), isNull);
  });

  test('insertTaskLinks keeps earlier anchors valid', () {
    const body = 'milk\nbread';
    final out = insertTaskLinks(body, [(4, 'a'), (10, 'b')]);
    expect(out, 'milk [→ task](nemo://task/a)\nbread [→ task](nemo://task/b)');
    expect(removeTaskLinks(out, {'a', 'b'}), body);
  });

  group('insertTaskLinksInValue', () {
    test('moves a cursor at an anchor past the link', () {
      final out = insertTaskLinksInValue(
        const TextEditingValue(
          text: '- [ ] milk',
          selection: TextSelection.collapsed(offset: 10),
        ),
        [(10, 'a')],
      );
      expect(out.text, '- [ ] milk [→ task](nemo://task/a)');
      expect(out.selection, TextSelection.collapsed(offset: out.text.length));
    });

    test('collapses to the old selection end, shifted past the links '
        'before it', () {
      const link = ' [→ task](nemo://task/a)';
      final out = insertTaskLinksInValue(
        const TextEditingValue(
          text: 'milk\nbread',
          selection: TextSelection(baseOffset: 2, extentOffset: 10),
        ),
        [(4, 'a'), (10, 'b')],
      );
      expect(
        out.text,
        'milk [→ task](nemo://task/a)\nbread [→ task](nemo://task/b)',
      );
      expect(out.selection, TextSelection.collapsed(offset: out.text.length));
      expect(out.text.indexOf('\n'), 4 + link.length);
    });

    test('does not extend a selection ending before a link over it', () {
      final out = insertTaskLinksInValue(
        const TextEditingValue(
          text: 'milk\nbread',
          selection: TextSelection(baseOffset: 0, extentOffset: 4),
        ),
        [(4, 'a')],
      );
      expect(out.text, 'milk [→ task](nemo://task/a)\nbread');
      expect(
        out.selection,
        const TextSelection.collapsed(
          offset: 4 + ' [→ task](nemo://task/a)'.length,
        ),
      );
    });
  });

  test('appendTaskLink puts the link on a new last line, and undoes', () {
    expect(appendTaskLink('', 'a'), '[→ task](nemo://task/a)');
    final out = appendTaskLink('text\n', 'a');
    expect(out, 'text\n\n[→ task](nemo://task/a)');
    expect(removeTaskLinks(out, {'a'}), 'text\n');
    expect(removeTaskLinks(appendTaskLink('', 'a'), {'a'}), '');
  });

  test("removeTaskLinks leaves other tasks' links alone", () {
    const body = 'a [→ task](nemo://task/x) b [→ task](nemo://task/y)';
    expect(removeTaskLinks(body, {'x'}), 'a b [→ task](nemo://task/y)');
  });

  group('removeTaskLinksInValue', () {
    test('shifts a cursor after the link left by what was removed', () {
      const text = '- [ ] milk [→ task](nemo://task/a)';
      final out = removeTaskLinksInValue(_sel(text, text.length), {'a'});
      expect(out.text, '- [ ] milk');
      expect(out.selection, TextSelection.collapsed(offset: out.text.length));
    });

    test('sums the removed links before a cursor past several of them', () {
      const text =
          'milk [→ task](nemo://task/a)\nbread [→ task](nemo://task/b)';
      final out = removeTaskLinksInValue(_sel(text, text.length), {'a', 'b'});
      expect(out.text, 'milk\nbread');
      expect(out.selection, TextSelection.collapsed(offset: out.text.length));
    });

    test('leaves a cursor before the link alone', () {
      const text = 'one\nmilk [→ task](nemo://task/a)\nthree';
      final out = removeTaskLinksInValue(_sel(text, 0), {'a'});
      expect(out.text, 'one\nmilk\nthree');
      expect(out.selection, const TextSelection.collapsed(offset: 0));
    });

    test('leaves a range selection where it was', () {
      const text = 'milk [→ task](nemo://task/a)\nbread';
      const sel = TextSelection(baseOffset: 0, extentOffset: 4);
      final out = removeTaskLinksInValue(
        const TextEditingValue(text: text, selection: sel),
        {'a'},
      );
      expect(out.text, 'milk\nbread');
      expect(out.selection, sel);
    });
  });

  test('wholeNoteTodo splits out the open checklist', () {
    final w = wholeNoteTodo(
      'Shop',
      'For Sunday\n- [ ] milk\n- [x] eggs\n'
          '- [ ] **jam**',
    );
    expect(w.title, 'Shop');
    expect(w.checklist, ['milk', 'jam']);
    expect(w.notes, 'For Sunday\n- [ ] milk\n- [x] eggs\n- [ ] **jam**');
    expect(w.notesWithoutChecklist, 'For Sunday\n- [x] eggs');
  });

  test('wholeNoteTodo leaves existing task links out of the notes', () {
    final w = wholeNoteTodo(
      'Shop',
      'call Bob [→ task](nemo://task/t1)\n- [ ] milk\n'
          '[→ task](nemo://task/t2)',
    );
    expect(w.notes, 'call Bob\n- [ ] milk');
    expect(w.notesWithoutChecklist, 'call Bob');
    expect(w.checklist, ['milk']);
  });
}
