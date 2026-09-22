// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Photo _$PhotoFromJson(Map<String, dynamic> json) => _Photo(
  id: json['id'] as String,
  parentId: json['task_id'] as String,
  sha256: json['sha256'] as String,
  byteSize: (json['byte_size'] as num).toInt(),
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  sortKey: json['sort_key'] as String,
  updatedAt: json['updated_at'] as String,
  parentKind:
      $enumDecodeNullable(_$PhotoParentEnumMap, json['parent_kind']) ??
      PhotoParent.task,
  deletedAt: json['deleted_at'] as String?,
);

Map<String, dynamic> _$PhotoToJson(_Photo instance) => <String, dynamic>{
  'id': instance.id,
  'task_id': instance.parentId,
  'sha256': instance.sha256,
  'byte_size': instance.byteSize,
  'width': instance.width,
  'height': instance.height,
  'sort_key': instance.sortKey,
  'updated_at': instance.updatedAt,
  'parent_kind': _$PhotoParentEnumMap[instance.parentKind]!,
  'deleted_at': instance.deletedAt,
};

const _$PhotoParentEnumMap = {
  PhotoParent.task: 'task',
  PhotoParent.note: 'note',
};
