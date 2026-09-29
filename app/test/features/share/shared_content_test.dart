import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/share/data/shared_content.dart';

void main() {
  ShareDraft draft({String? text, String? subject, List<Uint8List>? images}) =>
      ShareDraft.from(
        SharedContent(text: text, subject: subject, images: images ?? []),
      );

  test('a single line of text is the title, with no notes', () {
    final d = draft(text: '  Buy milk  ');
    expect(d.title, 'Buy milk');
    expect(d.notes, '');
  });

  test('the first line is the title and the rest the notes', () {
    final d = draft(text: '\nCall the plumber\nKitchen tap drips\n\nAsk price');
    expect(d.title, 'Call the plumber');
    expect(d.notes, 'Kitchen tap drips\n\nAsk price');
  });

  test('a subject is the title, and the whole text the notes', () {
    final d = draft(
      subject: 'Pasta recipe\n from Anna',
      text: 'https://example.com/pasta',
    );
    expect(d.title, 'Pasta recipe from Anna');
    expect(d.notes, 'https://example.com/pasta');
  });

  test('a subject repeated as the text leaves no notes', () {
    final d = draft(subject: 'Same', text: 'Same');
    expect(d.title, 'Same');
    expect(d.notes, '');
  });

  test('a link on its own is both the title and the notes', () {
    final d = draft(text: ' https://example.com/a?b=c#d ');
    expect(d.title, 'https://example.com/a?b=c#d');
    expect(d.notes, 'https://example.com/a?b=c#d');
  });

  test('a link inside a sentence is just text', () {
    final d = draft(text: 'Read https://example.com later');
    expect(d.title, 'Read https://example.com later');
    expect(d.notes, '');
  });

  test('a long first line is cut on a word and kept whole in the notes', () {
    final long = List.filled(40, 'word').join(' ');
    final d = draft(text: long);
    expect(d.title.length, lessThanOrEqualTo(ShareDraft.maxTitle + 1));
    expect(d.title, endsWith('word…'));
    expect(d.notes, long);
  });

  test('a long line without spaces is cut where it reaches the limit', () {
    final long = 'x' * 200;
    final d = draft(text: long);
    expect(d.title, '${'x' * ShareDraft.maxTitle}…');
    expect(d.notes, long);
  });

  test('pictures pass through, and pictures alone leave the title empty', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final d = draft(images: [bytes]);
    expect(d.title, '');
    expect(d.notes, '');
    expect(d.images, [bytes]);
  });

  test('blank text and a blank subject give an empty draft', () {
    final d = draft(text: '  \n ', subject: '  ');
    expect(d.title, '');
    expect(d.notes, '');
  });
}
