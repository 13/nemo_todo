import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';

part 'photo.freezed.dart';
part 'photo.g.dart';

/// A picture attached to a task.
///
/// The row carries the SHA-256 of the bytes rather than the bytes: the
/// picture itself travels over the blob channel, which needs no merge
/// rules because a hash never names two different images.
@freezed
abstract class Photo with _$Photo implements SyncRow {
  const factory Photo({
    required String id,
    required String taskId,

    /// Lowercase hex SHA-256 of the processed bytes.
    required String sha256,
    required int byteSize,
    required int width,
    required int height,
    required String sortKey,
    required String updatedAt,
    String? deletedAt,
  }) = _Photo;

  const Photo._();

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  bool get isDeleted => deletedAt != null;
}
