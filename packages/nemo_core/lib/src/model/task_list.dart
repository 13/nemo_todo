import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';

part 'task_list.freezed.dart';
part 'task_list.g.dart';

/// A list of tasks. `ownerId` is authored by the server and null while the
/// list exists only on this device.
@freezed
abstract class TaskList with _$TaskList implements SyncRow {
  const factory TaskList({
    required String id,
    required String name,
    required String sortKey,
    required String updatedAt,
    @Default(0) int color,
    @Default('list') String icon,
    String? ownerId,
    @Default(false) bool isInbox,
    String? deletedAt,
  }) = _TaskList;

  const TaskList._();

  factory TaskList.fromJson(Map<String, dynamic> json) =>
      _$TaskListFromJson(json);

  bool get isDeleted => deletedAt != null;
}
