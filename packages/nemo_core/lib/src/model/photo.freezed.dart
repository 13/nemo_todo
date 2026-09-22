// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Photo {

 String get id;/// The task or note this picture hangs on, depending on [parentKind].
///
/// Still spelled `task_id` on the wire. Renaming it would break every
/// client that has not been updated, and a client that cannot read
/// notes is never sent a photo whose parent is one.
@JsonKey(name: 'task_id') String get parentId;/// Absent on the wire from a client or server released before notes,
/// where it could only ever have meant a task.
 PhotoParent get parentKind;/// Lowercase hex SHA-256 of the processed bytes.
 String get sha256; int get byteSize; int get width; int get height; String get sortKey; String get updatedAt; String? get deletedAt;
/// Create a copy of Photo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoCopyWith<Photo> get copyWith => _$PhotoCopyWithImpl<Photo>(this as Photo, _$identity);

  /// Serializes this Photo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Photo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Photo&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.parentId, _this.parentId) || other.parentId == _this.parentId)&&(identical(other.parentKind, _this.parentKind) || other.parentKind == _this.parentKind)&&(identical(other.sha256, _this.sha256) || other.sha256 == _this.sha256)&&(identical(other.byteSize, _this.byteSize) || other.byteSize == _this.byteSize)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.sortKey, _this.sortKey) || other.sortKey == _this.sortKey)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.deletedAt, _this.deletedAt) || other.deletedAt == _this.deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Photo;
  return Object.hash(runtimeType,_this.id,_this.parentId,_this.parentKind,_this.sha256,_this.byteSize,_this.width,_this.height,_this.sortKey,_this.updatedAt,_this.deletedAt);
}

@override
String toString() {
  final _this = this as Photo;
  return 'Photo(id: ${_this.id}, parentId: ${_this.parentId}, parentKind: ${_this.parentKind}, sha256: ${_this.sha256}, byteSize: ${_this.byteSize}, width: ${_this.width}, height: ${_this.height}, sortKey: ${_this.sortKey}, updatedAt: ${_this.updatedAt}, deletedAt: ${_this.deletedAt})';
}


}

/// @nodoc
abstract mixin class $PhotoCopyWith<$Res>  {
  factory $PhotoCopyWith(Photo value, $Res Function(Photo) _then) = _$PhotoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'task_id') String parentId, PhotoParent parentKind, String sha256, int byteSize, int width, int height, String sortKey, String updatedAt, String? deletedAt
});




}
/// @nodoc
class _$PhotoCopyWithImpl<$Res>
    implements $PhotoCopyWith<$Res> {
  _$PhotoCopyWithImpl(this._self, this._then);

  final Photo _self;
  final $Res Function(Photo) _then;

/// Create a copy of Photo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? parentId = null,Object? parentKind = null,Object? sha256 = null,Object? byteSize = null,Object? width = null,Object? height = null,Object? sortKey = null,Object? updatedAt = null,Object? deletedAt = freezed,}) {
  return _then(Photo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: null == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String,parentKind: null == parentKind ? _self.parentKind : parentKind // ignore: cast_nullable_to_non_nullable
as PhotoParent,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,byteSize: null == byteSize ? _self.byteSize : byteSize // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,sortKey: null == sortKey ? _self.sortKey : sortKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Photo].
extension PhotoPatterns on Photo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Photo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Photo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Photo value)  $default,){
final _that = this;
switch (_that) {
case _Photo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Photo value)?  $default,){
final _that = this;
switch (_that) {
case _Photo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'task_id')  String parentId,  PhotoParent parentKind,  String sha256,  int byteSize,  int width,  int height,  String sortKey,  String updatedAt,  String? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Photo() when $default != null:
return $default(_that.id,_that.parentId,_that.parentKind,_that.sha256,_that.byteSize,_that.width,_that.height,_that.sortKey,_that.updatedAt,_that.deletedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'task_id')  String parentId,  PhotoParent parentKind,  String sha256,  int byteSize,  int width,  int height,  String sortKey,  String updatedAt,  String? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _Photo():
return $default(_that.id,_that.parentId,_that.parentKind,_that.sha256,_that.byteSize,_that.width,_that.height,_that.sortKey,_that.updatedAt,_that.deletedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'task_id')  String parentId,  PhotoParent parentKind,  String sha256,  int byteSize,  int width,  int height,  String sortKey,  String updatedAt,  String? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _Photo() when $default != null:
return $default(_that.id,_that.parentId,_that.parentKind,_that.sha256,_that.byteSize,_that.width,_that.height,_that.sortKey,_that.updatedAt,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Photo extends Photo {
  const _Photo({required this.id, @JsonKey(name: 'task_id') required this.parentId, this.parentKind = PhotoParent.task, required this.sha256, required this.byteSize, required this.width, required this.height, required this.sortKey, required this.updatedAt, this.deletedAt}): super._();
  factory _Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

@override final  String id;
/// The task or note this picture hangs on, depending on [parentKind].
///
/// Still spelled `task_id` on the wire. Renaming it would break every
/// client that has not been updated, and a client that cannot read
/// notes is never sent a photo whose parent is one.
@override@JsonKey(name: 'task_id') final  String parentId;
/// Absent on the wire from a client or server released before notes,
/// where it could only ever have meant a task.
@override@JsonKey() final  PhotoParent parentKind;
/// Lowercase hex SHA-256 of the processed bytes.
@override final  String sha256;
@override final  int byteSize;
@override final  int width;
@override final  int height;
@override final  String sortKey;
@override final  String updatedAt;
@override final  String? deletedAt;

/// Create a copy of Photo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoCopyWith<_Photo> get copyWith => __$PhotoCopyWithImpl<_Photo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhotoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Photo&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.parentKind, parentKind) || other.parentKind == parentKind)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.byteSize, byteSize) || other.byteSize == byteSize)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.sortKey, sortKey) || other.sortKey == sortKey)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,parentId,parentKind,sha256,byteSize,width,height,sortKey,updatedAt,deletedAt);
}

@override
String toString() {
    return 'Photo(id: $id, parentId: $parentId, parentKind: $parentKind, sha256: $sha256, byteSize: $byteSize, width: $width, height: $height, sortKey: $sortKey, updatedAt: $updatedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$PhotoCopyWith<$Res> implements $PhotoCopyWith<$Res> {
  factory _$PhotoCopyWith(_Photo value, $Res Function(_Photo) _then) = __$PhotoCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'task_id') String parentId, PhotoParent parentKind, String sha256, int byteSize, int width, int height, String sortKey, String updatedAt, String? deletedAt
});




}
/// @nodoc
class __$PhotoCopyWithImpl<$Res>
    implements _$PhotoCopyWith<$Res> {
  __$PhotoCopyWithImpl(this._self, this._then);

  final _Photo _self;
  final $Res Function(_Photo) _then;

/// Create a copy of Photo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = null,Object? parentKind = null,Object? sha256 = null,Object? byteSize = null,Object? width = null,Object? height = null,Object? sortKey = null,Object? updatedAt = null,Object? deletedAt = freezed,}) {
  return _then(_Photo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: null == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String,parentKind: null == parentKind ? _self.parentKind : parentKind // ignore: cast_nullable_to_non_nullable
as PhotoParent,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,byteSize: null == byteSize ? _self.byteSize : byteSize // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,sortKey: null == sortKey ? _self.sortKey : sortKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
