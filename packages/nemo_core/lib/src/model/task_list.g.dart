// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskList _$TaskListFromJson(Map<String, dynamic> json) => _TaskList(
  id: json['id'] as String,
  name: json['name'] as String,
  sortKey: json['sort_key'] as String,
  updatedAt: json['updated_at'] as String,
  color: (json['color'] as num?)?.toInt() ?? 0,
  icon: json['icon'] as String? ?? 'list',
  ownerId: json['owner_id'] as String?,
  isInbox: json['is_inbox'] as bool? ?? false,
  deletedAt: json['deleted_at'] as String?,
);

Map<String, dynamic> _$TaskListToJson(_TaskList instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'sort_key': instance.sortKey,
  'updated_at': instance.updatedAt,
  'color': instance.color,
  'icon': instance.icon,
  'owner_id': instance.ownerId,
  'is_inbox': instance.isInbox,
  'deleted_at': instance.deletedAt,
};
