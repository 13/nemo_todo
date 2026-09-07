import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/subtask.dart';
import 'package:nemo_core/src/model/task.dart';
import 'package:nemo_core/src/model/task_list.dart';

part 'sync.freezed.dart';
part 'sync.g.dart';

/// The kinds of rows that travel through the sync endpoint.
enum SyncEntity { list, task, subtask }

/// What a user may do with a shared list.
enum MemberRole { owner, editor }

/// One change in a sync request or response.
///
/// `list`, `task` and `subtask` carry a full row; `revoke` tells the
/// receiver to delete its local copy of a row it may no longer see.
@Freezed(unionKey: 'type')
sealed class SyncChange with _$SyncChange {
  const factory SyncChange.list(TaskList row) = SyncChangeList;
  const factory SyncChange.task(Task row) = SyncChangeTask;
  const factory SyncChange.subtask(Subtask row) = SyncChangeSubtask;
  const factory SyncChange.revoke({
    required SyncEntity target,
    required String id,
  }) = SyncChangeRevoke;

  const SyncChange._();

  factory SyncChange.fromJson(Map<String, dynamic> json) =>
      _$SyncChangeFromJson(json);

  SyncEntity get entity => switch (this) {
    SyncChangeList() => SyncEntity.list,
    SyncChangeTask() => SyncEntity.task,
    SyncChangeSubtask() => SyncEntity.subtask,
    SyncChangeRevoke(:final target) => target,
  };

  String get rowId => switch (this) {
    SyncChangeList(:final row) => row.id,
    SyncChangeTask(:final row) => row.id,
    SyncChangeSubtask(:final row) => row.id,
    SyncChangeRevoke(:final id) => id,
  };
}

@freezed
abstract class SyncRequest with _$SyncRequest {
  const factory SyncRequest({
    required int cursor,
    @Default(<SyncChange>[]) List<SyncChange> changes,
  }) = _SyncRequest;

  factory SyncRequest.fromJson(Map<String, dynamic> json) =>
      _$SyncRequestFromJson(json);
}

@freezed
abstract class RejectedChange with _$RejectedChange {
  const factory RejectedChange({
    required SyncEntity entity,
    required String rowId,
    required String reason,
  }) = _RejectedChange;

  factory RejectedChange.fromJson(Map<String, dynamic> json) =>
      _$RejectedChangeFromJson(json);
}

@freezed
abstract class ListMember with _$ListMember {
  const factory ListMember({
    required String username,
    required MemberRole role,
  }) = _ListMember;

  factory ListMember.fromJson(Map<String, dynamic> json) =>
      _$ListMemberFromJson(json);
}

@freezed
abstract class SyncResponse with _$SyncResponse {
  const factory SyncResponse({
    required int cursor,
    required String serverHlc,
    @Default(<SyncChange>[]) List<SyncChange> changes,
    @Default(<RejectedChange>[]) List<RejectedChange> rejected,
    @Default(<String, List<ListMember>>{})
    Map<String, List<ListMember>> members,
    @Default(false) bool hasMore,
  }) = _SyncResponse;

  factory SyncResponse.fromJson(Map<String, dynamic> json) =>
      _$SyncResponseFromJson(json);
}
