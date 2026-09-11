import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';
import 'package:nemo_core/src/repeat.dart';

part 'task.freezed.dart';
part 'task.g.dart';

/// A todo item. Times are UTC milliseconds since the epoch; `dueHasTime`
/// says whether `dueAt` carries a time of day or only a date.
@freezed
abstract class Task with _$Task implements SyncRow {
  const factory Task({
    required String id,
    required String listId,
    required String title,
    required String sortKey,
    required String updatedAt,
    @Default('') String notes,
    @Default(false) bool done,
    int? doneAt,
    int? dueAt,
    @Default(false) bool dueHasTime,
    @Default(false) bool remind,
    @Default(0) int priority,
    @Default(<String>[]) List<String> tags,

    /// A [Repeat] rule as text, or null for a task that happens once. Kept
    /// as text so a rule from a newer version travels through this one and
    /// through the server intact instead of being dropped.
    String? repeat,
    String? deletedAt,
  }) = _Task;

  const Task._();

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  bool get isDeleted => deletedAt != null;

  /// The rule this task repeats on, if it repeats and this version can
  /// read the rule.
  Repeat? get repeatRule => Repeat.tryParse(repeat);
}
