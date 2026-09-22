import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';

part 'photo.freezed.dart';
part 'photo.g.dart';

/// What a picture hangs on.
enum PhotoParent { task, note }

/// A picture attached to a task or a note.
///
/// The row carries the SHA-256 of the bytes rather than the bytes: the
/// picture itself travels over the blob channel, which needs no merge
/// rules because a hash never names two different images.
@freezed
abstract class Photo with _$Photo implements SyncRow {
  const factory Photo({
    required String id,

    /// The task or note this picture hangs on, depending on [parentKind].
    ///
    /// Still spelled `task_id` on the wire. Renaming it would break every
    /// client that has not been updated, and a client that cannot read
    /// notes is never sent a photo whose parent is one.
    @JsonKey(name: 'task_id') required String parentId,

    /// Lowercase hex SHA-256 of the processed bytes.
    required String sha256,
    required int byteSize,
    required int width,
    required int height,
    required String sortKey,
    required String updatedAt,

    /// Absent on the wire from a client or server released before notes,
    /// where it could only ever have meant a task.
    @Default(PhotoParent.task) PhotoParent parentKind,

    String? deletedAt,
  }) = _Photo;

  const Photo._();

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  bool get isDeleted => deletedAt != null;
}
