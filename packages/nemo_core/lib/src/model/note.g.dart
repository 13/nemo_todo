// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Note _$NoteFromJson(Map<String, dynamic> json) => _Note(
  id: json['id'] as String,
  listId: json['list_id'] as String,
  title: json['title'] as String,
  sortKey: json['sort_key'] as String,
  updatedAt: json['updated_at'] as String,
  body: json['body'] as String? ?? '',
  pinned: json['pinned'] as bool? ?? false,
  deletedAt: json['deleted_at'] as String?,
);

Map<String, dynamic> _$NoteToJson(_Note instance) => <String, dynamic>{
  'id': instance.id,
  'list_id': instance.listId,
  'title': instance.title,
  'sort_key': instance.sortKey,
  'updated_at': instance.updatedAt,
  'body': instance.body,
  'pinned': instance.pinned,
  'deleted_at': instance.deletedAt,
};
