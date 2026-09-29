import 'dart:typed_data';

import 'package:meta/meta.dart';

/// What another app handed nemo through the system share sheet, as it
/// arrived: nothing here has been read or re-encoded yet.
@immutable
class SharedContent {
  const SharedContent({this.text, this.subject, this.images = const []});

  /// `EXTRA_TEXT`: a message, a note, or -- from a browser -- a link.
  final String? text;

  /// `EXTRA_SUBJECT`: a browser's page title, an email's subject.
  final String? subject;

  /// The shared files' bytes, which should be pictures but are not
  /// promised to be.
  final List<Uint8List> images;
}

/// A task not yet written: what the share sheet opens with.
@immutable
class ShareDraft {
  const ShareDraft({this.title = '', this.notes = '', this.images = const []});

  /// Reads [content] the way a person would file it: a subject is the
  /// title and the text its notes; otherwise the first line is the title
  /// and the rest the notes. A link on its own is the title and the notes
  /// both, so it is still there -- and tappable -- after the title is
  /// reworded.
  factory ShareDraft.from(SharedContent content) {
    final text = content.text?.trim() ?? '';
    final subject = _oneLine(content.subject ?? '');
    if (subject.isNotEmpty) {
      return ShareDraft(
        title: _cut(subject).title,
        notes: text == subject ? '' : text,
        images: content.images,
      );
    }
    if (_isLink(text)) {
      return ShareDraft(title: text, notes: text, images: content.images);
    }
    final lines = text.split('\n');
    final first = lines.first.trim();
    final rest = lines.skip(1).join('\n').trim();
    final cut = _cut(first);
    return ShareDraft(
      title: cut.title,
      notes: cut.whole ? rest : text,
      images: content.images,
    );
  }

  /// The longest title the draft proposes; a longer first line is cut on
  /// a word and kept whole in the notes.
  static const maxTitle = 120;

  final String title;
  final String notes;
  final List<Uint8List> images;
}

bool _isLink(String text) =>
    !text.contains(RegExp(r'\s')) &&
    RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(text);

String _oneLine(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

({String title, bool whole}) _cut(String line) {
  if (line.length <= ShareDraft.maxTitle) return (title: line, whole: true);
  final head = line.substring(0, ShareDraft.maxTitle);
  final space = head.lastIndexOf(' ');
  final title = (space > ShareDraft.maxTitle ~/ 2)
      ? head.substring(0, space)
      : head;
  return (title: '${title.trimRight()}…', whole: false);
}
