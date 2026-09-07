import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';

part 'subtask.freezed.dart';
part 'subtask.g.dart';

/// A checklist item under a task.
@freezed
abstract class Subtask with _$Subtask implements SyncRow {
  const factory Subtask({
    required String id,
    required String taskId,
    required String title,
    required String sortKey,
    required String updatedAt,
    @Default(false) bool done,
    String? deletedAt,
  }) = _Subtask;

  const Subtask._();

  factory Subtask.fromJson(Map<String, dynamic> json) =>
      _$SubtaskFromJson(json);

  bool get isDeleted => deletedAt != null;
}
