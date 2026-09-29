import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';
import 'package:nemo_core/src/task_order.dart';

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

    /// How the list's tasks are sorted: a [TaskOrder]'s wire value. Text
    /// rather than the enum, so an order a newer version knows travels
    /// through this one and the server intact instead of being dropped.
    @Default('manual') String taskOrder,
    String? deletedAt,
  }) = _TaskList;

  const TaskList._();

  factory TaskList.fromJson(Map<String, dynamic> json) =>
      _$TaskListFromJson(json);

  bool get isDeleted => deletedAt != null;

  /// The order this list's tasks are shown in; manual for one this version
  /// does not know.
  TaskOrder get order => TaskOrder.parse(taskOrder);
}
