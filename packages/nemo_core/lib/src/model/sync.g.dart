// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncChangeList _$SyncChangeListFromJson(Map<String, dynamic> json) =>
    SyncChangeList(
      TaskList.fromJson(json['row'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SyncChangeListToJson(SyncChangeList instance) =>
    <String, dynamic>{'row': instance.row.toJson(), 'type': instance.$type};

SyncChangeTask _$SyncChangeTaskFromJson(Map<String, dynamic> json) =>
    SyncChangeTask(
      Task.fromJson(json['row'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SyncChangeTaskToJson(SyncChangeTask instance) =>
    <String, dynamic>{'row': instance.row.toJson(), 'type': instance.$type};

SyncChangeSubtask _$SyncChangeSubtaskFromJson(Map<String, dynamic> json) =>
    SyncChangeSubtask(
      Subtask.fromJson(json['row'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SyncChangeSubtaskToJson(SyncChangeSubtask instance) =>
    <String, dynamic>{'row': instance.row.toJson(), 'type': instance.$type};

SyncChangeRevoke _$SyncChangeRevokeFromJson(Map<String, dynamic> json) =>
    SyncChangeRevoke(
      target: $enumDecode(_$SyncEntityEnumMap, json['target']),
      id: json['id'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SyncChangeRevokeToJson(SyncChangeRevoke instance) =>
    <String, dynamic>{
      'target': _$SyncEntityEnumMap[instance.target]!,
      'id': instance.id,
      'type': instance.$type,
    };

const _$SyncEntityEnumMap = {
  SyncEntity.list: 'list',
  SyncEntity.task: 'task',
  SyncEntity.subtask: 'subtask',
};

_SyncRequest _$SyncRequestFromJson(Map<String, dynamic> json) => _SyncRequest(
  cursor: (json['cursor'] as num).toInt(),
  changes:
      (json['changes'] as List<dynamic>?)
          ?.map((e) => SyncChange.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SyncChange>[],
);

Map<String, dynamic> _$SyncRequestToJson(_SyncRequest instance) =>
    <String, dynamic>{
      'cursor': instance.cursor,
      'changes': instance.changes.map((e) => e.toJson()).toList(),
    };

_RejectedChange _$RejectedChangeFromJson(Map<String, dynamic> json) =>
    _RejectedChange(
      entity: $enumDecode(_$SyncEntityEnumMap, json['entity']),
      rowId: json['row_id'] as String,
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$RejectedChangeToJson(_RejectedChange instance) =>
    <String, dynamic>{
      'entity': _$SyncEntityEnumMap[instance.entity]!,
      'row_id': instance.rowId,
      'reason': instance.reason,
    };

_ListMember _$ListMemberFromJson(Map<String, dynamic> json) => _ListMember(
  username: json['username'] as String,
  role: $enumDecode(_$MemberRoleEnumMap, json['role']),
);

Map<String, dynamic> _$ListMemberToJson(_ListMember instance) =>
    <String, dynamic>{
      'username': instance.username,
      'role': _$MemberRoleEnumMap[instance.role]!,
    };

const _$MemberRoleEnumMap = {
  MemberRole.owner: 'owner',
  MemberRole.editor: 'editor',
};

_SyncResponse _$SyncResponseFromJson(Map<String, dynamic> json) =>
    _SyncResponse(
      cursor: (json['cursor'] as num).toInt(),
      serverHlc: json['server_hlc'] as String,
      changes:
          (json['changes'] as List<dynamic>?)
              ?.map((e) => SyncChange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SyncChange>[],
      rejected:
          (json['rejected'] as List<dynamic>?)
              ?.map((e) => RejectedChange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RejectedChange>[],
      members:
          (json['members'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
              k,
              (e as List<dynamic>)
                  .map((e) => ListMember.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          ) ??
          const <String, List<ListMember>>{},
      hasMore: json['has_more'] as bool? ?? false,
      serverVersion: json['server_version'] as String? ?? '',
    );

Map<String, dynamic> _$SyncResponseToJson(_SyncResponse instance) =>
    <String, dynamic>{
      'cursor': instance.cursor,
      'server_hlc': instance.serverHlc,
      'changes': instance.changes.map((e) => e.toJson()).toList(),
      'rejected': instance.rejected.map((e) => e.toJson()).toList(),
      'members': instance.members.map(
        (k, e) => MapEntry(k, e.map((e) => e.toJson()).toList()),
      ),
      'has_more': instance.hasMore,
      'server_version': instance.serverVersion,
    };
