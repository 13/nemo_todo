import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';

part 'note.freezed.dart';
part 'note.g.dart';

/// A note in a list: a title and a body of markdown.
///
/// The body is the text the person typed, not a rendered document, so it
/// searches, exports and merges like every other string here -- markdown
/// is something the app draws, not something the protocol knows about.
@freezed
abstract class Note with _$Note implements SyncRow {
  const factory Note({
    required String id,
    required String listId,
    required String title,
    required String sortKey,
    required String updatedAt,
    @Default('') String body,
    @Default(false) bool pinned,
    String? deletedAt,
  }) = _Note;

  const Note._();

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  bool get isDeleted => deletedAt != null;
}
