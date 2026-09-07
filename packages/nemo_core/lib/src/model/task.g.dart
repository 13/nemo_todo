// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Task _$TaskFromJson(Map<String, dynamic> json) => _Task(
  id: json['id'] as String,
  listId: json['list_id'] as String,
  title: json['title'] as String,
  sortKey: json['sort_key'] as String,
  updatedAt: json['updated_at'] as String,
  notes: json['notes'] as String? ?? '',
  done: json['done'] as bool? ?? false,
  doneAt: (json['done_at'] as num?)?.toInt(),
  dueAt: (json['due_at'] as num?)?.toInt(),
  dueHasTime: json['due_has_time'] as bool? ?? false,
  remind: json['remind'] as bool? ?? false,
  priority: (json['priority'] as num?)?.toInt() ?? 0,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  deletedAt: json['deleted_at'] as String?,
);

Map<String, dynamic> _$TaskToJson(_Task instance) => <String, dynamic>{
  'id': instance.id,
  'list_id': instance.listId,
  'title': instance.title,
  'sort_key': instance.sortKey,
  'updated_at': instance.updatedAt,
  'notes': instance.notes,
  'done': instance.done,
  'done_at': instance.doneAt,
  'due_at': instance.dueAt,
  'due_has_time': instance.dueHasTime,
  'remind': instance.remind,
  'priority': instance.priority,
  'tags': instance.tags,
  'deleted_at': instance.deletedAt,
};
