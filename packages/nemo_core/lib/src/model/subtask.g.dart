// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtask.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Subtask _$SubtaskFromJson(Map<String, dynamic> json) => _Subtask(
  id: json['id'] as String,
  taskId: json['task_id'] as String,
  title: json['title'] as String,
  sortKey: json['sort_key'] as String,
  updatedAt: json['updated_at'] as String,
  done: json['done'] as bool? ?? false,
  deletedAt: json['deleted_at'] as String?,
);

Map<String, dynamic> _$SubtaskToJson(_Subtask instance) => <String, dynamic>{
  'id': instance.id,
  'task_id': instance.taskId,
  'title': instance.title,
  'sort_key': instance.sortKey,
  'updated_at': instance.updatedAt,
  'done': instance.done,
  'deleted_at': instance.deletedAt,
};
