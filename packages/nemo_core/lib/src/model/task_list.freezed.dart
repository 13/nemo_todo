// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_list.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskList {

 String get id; String get name; String get sortKey; String get updatedAt; int get color; String get icon; String? get ownerId; bool get isInbox; String? get deletedAt;
/// Create a copy of TaskList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskListCopyWith<TaskList> get copyWith => _$TaskListCopyWithImpl<TaskList>(this as TaskList, _$identity);

  /// Serializes this TaskList to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaskList;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskList&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.sortKey, _this.sortKey) || other.sortKey == _this.sortKey)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.icon, _this.icon) || other.icon == _this.icon)&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.isInbox, _this.isInbox) || other.isInbox == _this.isInbox)&&(identical(other.deletedAt, _this.deletedAt) || other.deletedAt == _this.deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaskList;
  return Object.hash(runtimeType,_this.id,_this.name,_this.sortKey,_this.updatedAt,_this.color,_this.icon,_this.ownerId,_this.isInbox,_this.deletedAt);
}

@override
String toString() {
  final _this = this as TaskList;
  return 'TaskList(id: ${_this.id}, name: ${_this.name}, sortKey: ${_this.sortKey}, updatedAt: ${_this.updatedAt}, color: ${_this.color}, icon: ${_this.icon}, ownerId: ${_this.ownerId}, isInbox: ${_this.isInbox}, deletedAt: ${_this.deletedAt})';
}


}

/// @nodoc
abstract mixin class $TaskListCopyWith<$Res>  {
  factory $TaskListCopyWith(TaskList value, $Res Function(TaskList) _then) = _$TaskListCopyWithImpl;
@useResult
$Res call({
 String id, String name, String sortKey, String updatedAt, int color, String icon, String? ownerId, bool isInbox, String? deletedAt
});




}
/// @nodoc
class _$TaskListCopyWithImpl<$Res>
    implements $TaskListCopyWith<$Res> {
  _$TaskListCopyWithImpl(this._self, this._then);

  final TaskList _self;
  final $Res Function(TaskList) _then;

/// Create a copy of TaskList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sortKey = null,Object? updatedAt = null,Object? color = null,Object? icon = null,Object? ownerId = freezed,Object? isInbox = null,Object? deletedAt = freezed,}) {
  return _then(TaskList(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortKey: null == sortKey ? _self.sortKey : sortKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,ownerId: freezed == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String?,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskList].
extension TaskListPatterns on TaskList {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskList() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskList value)  $default,){
final _that = this;
switch (_that) {
case _TaskList():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskList value)?  $default,){
final _that = this;
switch (_that) {
case _TaskList() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String sortKey,  String updatedAt,  int color,  String icon,  String? ownerId,  bool isInbox,  String? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskList() when $default != null:
return $default(_that.id,_that.name,_that.sortKey,_that.updatedAt,_that.color,_that.icon,_that.ownerId,_that.isInbox,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String sortKey,  String updatedAt,  int color,  String icon,  String? ownerId,  bool isInbox,  String? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _TaskList():
return $default(_that.id,_that.name,_that.sortKey,_that.updatedAt,_that.color,_that.icon,_that.ownerId,_that.isInbox,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String sortKey,  String updatedAt,  int color,  String icon,  String? ownerId,  bool isInbox,  String? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _TaskList() when $default != null:
return $default(_that.id,_that.name,_that.sortKey,_that.updatedAt,_that.color,_that.icon,_that.ownerId,_that.isInbox,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskList extends TaskList {
  const _TaskList({required this.id, required this.name, required this.sortKey, required this.updatedAt, this.color = 0, this.icon = 'list', this.ownerId, this.isInbox = false, this.deletedAt}): super._();
  factory _TaskList.fromJson(Map<String, dynamic> json) => _$TaskListFromJson(json);

@override final  String id;
@override final  String name;
@override final  String sortKey;
@override final  String updatedAt;
@override@JsonKey() final  int color;
@override@JsonKey() final  String icon;
@override final  String? ownerId;
@override@JsonKey() final  bool isInbox;
@override final  String? deletedAt;

/// Create a copy of TaskList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskListCopyWith<_TaskList> get copyWith => __$TaskListCopyWithImpl<_TaskList>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskListToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskList&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortKey, sortKey) || other.sortKey == sortKey)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.color, color) || other.color == color)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.isInbox, isInbox) || other.isInbox == isInbox)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,sortKey,updatedAt,color,icon,ownerId,isInbox,deletedAt);
}

@override
String toString() {
    return 'TaskList(id: $id, name: $name, sortKey: $sortKey, updatedAt: $updatedAt, color: $color, icon: $icon, ownerId: $ownerId, isInbox: $isInbox, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$TaskListCopyWith<$Res> implements $TaskListCopyWith<$Res> {
  factory _$TaskListCopyWith(_TaskList value, $Res Function(_TaskList) _then) = __$TaskListCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String sortKey, String updatedAt, int color, String icon, String? ownerId, bool isInbox, String? deletedAt
});




}
/// @nodoc
class __$TaskListCopyWithImpl<$Res>
    implements _$TaskListCopyWith<$Res> {
  __$TaskListCopyWithImpl(this._self, this._then);

  final _TaskList _self;
  final $Res Function(_TaskList) _then;

/// Create a copy of TaskList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sortKey = null,Object? updatedAt = null,Object? color = null,Object? icon = null,Object? ownerId = freezed,Object? isInbox = null,Object? deletedAt = freezed,}) {
  return _then(_TaskList(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortKey: null == sortKey ? _self.sortKey : sortKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,ownerId: freezed == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String?,isInbox: null == isInbox ? _self.isInbox : isInbox // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
