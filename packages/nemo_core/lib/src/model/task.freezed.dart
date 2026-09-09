// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Task {

 String get id; String get listId; String get title; String get sortKey; String get updatedAt; String get notes; bool get done; int? get doneAt; int? get dueAt; bool get dueHasTime; bool get remind; int get priority; List<String> get tags;/// A [Repeat] rule as text, or null for a task that happens once. Kept
/// as text so a rule from a newer version travels through this one and
/// through the server intact instead of being dropped.
 String? get repeat; String? get deletedAt;
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCopyWith<Task> get copyWith => _$TaskCopyWithImpl<Task>(this as Task, _$identity);

  /// Serializes this Task to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Task;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Task&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.listId, _this.listId) || other.listId == _this.listId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.sortKey, _this.sortKey) || other.sortKey == _this.sortKey)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&(identical(other.done, _this.done) || other.done == _this.done)&&(identical(other.doneAt, _this.doneAt) || other.doneAt == _this.doneAt)&&(identical(other.dueAt, _this.dueAt) || other.dueAt == _this.dueAt)&&(identical(other.dueHasTime, _this.dueHasTime) || other.dueHasTime == _this.dueHasTime)&&(identical(other.remind, _this.remind) || other.remind == _this.remind)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.repeat, _this.repeat) || other.repeat == _this.repeat)&&(identical(other.deletedAt, _this.deletedAt) || other.deletedAt == _this.deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Task;
  return Object.hash(runtimeType,_this.id,_this.listId,_this.title,_this.sortKey,_this.updatedAt,_this.notes,_this.done,_this.doneAt,_this.dueAt,_this.dueHasTime,_this.remind,_this.priority,const DeepCollectionEquality().hash(_this.tags),_this.repeat,_this.deletedAt);
}

@override
String toString() {
  final _this = this as Task;
  return 'Task(id: ${_this.id}, listId: ${_this.listId}, title: ${_this.title}, sortKey: ${_this.sortKey}, updatedAt: ${_this.updatedAt}, notes: ${_this.notes}, done: ${_this.done}, doneAt: ${_this.doneAt}, dueAt: ${_this.dueAt}, dueHasTime: ${_this.dueHasTime}, remind: ${_this.remind}, priority: ${_this.priority}, tags: ${_this.tags}, repeat: ${_this.repeat}, deletedAt: ${_this.deletedAt})';
}


}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res>  {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) = _$TaskCopyWithImpl;
@useResult
$Res call({
 String id, String listId, String title, String sortKey, String updatedAt, String notes, bool done, int? doneAt, int? dueAt, bool dueHasTime, bool remind, int priority, List<String> tags, String? repeat, String? deletedAt
});




}
/// @nodoc
class _$TaskCopyWithImpl<$Res>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? listId = null,Object? title = null,Object? sortKey = null,Object? updatedAt = null,Object? notes = null,Object? done = null,Object? doneAt = freezed,Object? dueAt = freezed,Object? dueHasTime = null,Object? remind = null,Object? priority = null,Object? tags = null,Object? repeat = freezed,Object? deletedAt = freezed,}) {
  return _then(Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,listId: null == listId ? _self.listId : listId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,sortKey: null == sortKey ? _self.sortKey : sortKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,doneAt: freezed == doneAt ? _self.doneAt : doneAt // ignore: cast_nullable_to_non_nullable
as int?,dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as int?,dueHasTime: null == dueHasTime ? _self.dueHasTime : dueHasTime // ignore: cast_nullable_to_non_nullable
as bool,remind: null == remind ? _self.remind : remind // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,repeat: freezed == repeat ? _self.repeat : repeat // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Task].
extension TaskPatterns on Task {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Task value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Task value)  $default,){
final _that = this;
switch (_that) {
case _Task():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Task value)?  $default,){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String listId,  String title,  String sortKey,  String updatedAt,  String notes,  bool done,  int? doneAt,  int? dueAt,  bool dueHasTime,  bool remind,  int priority,  List<String> tags,  String? repeat,  String? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.listId,_that.title,_that.sortKey,_that.updatedAt,_that.notes,_that.done,_that.doneAt,_that.dueAt,_that.dueHasTime,_that.remind,_that.priority,_that.tags,_that.repeat,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String listId,  String title,  String sortKey,  String updatedAt,  String notes,  bool done,  int? doneAt,  int? dueAt,  bool dueHasTime,  bool remind,  int priority,  List<String> tags,  String? repeat,  String? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _Task():
return $default(_that.id,_that.listId,_that.title,_that.sortKey,_that.updatedAt,_that.notes,_that.done,_that.doneAt,_that.dueAt,_that.dueHasTime,_that.remind,_that.priority,_that.tags,_that.repeat,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String listId,  String title,  String sortKey,  String updatedAt,  String notes,  bool done,  int? doneAt,  int? dueAt,  bool dueHasTime,  bool remind,  int priority,  List<String> tags,  String? repeat,  String? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.listId,_that.title,_that.sortKey,_that.updatedAt,_that.notes,_that.done,_that.doneAt,_that.dueAt,_that.dueHasTime,_that.remind,_that.priority,_that.tags,_that.repeat,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Task extends Task {
  const _Task({required this.id, required this.listId, required this.title, required this.sortKey, required this.updatedAt, this.notes = '', this.done = false, this.doneAt, this.dueAt, this.dueHasTime = false, this.remind = false, this.priority = 0,  List<String> tags = const <String>[], this.repeat, this.deletedAt}): _tags = tags,super._();
  factory _Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

@override final  String id;
@override final  String listId;
@override final  String title;
@override final  String sortKey;
@override final  String updatedAt;
@override@JsonKey() final  String notes;
@override@JsonKey() final  bool done;
@override final  int? doneAt;
@override final  int? dueAt;
@override@JsonKey() final  bool dueHasTime;
@override@JsonKey() final  bool remind;
@override@JsonKey() final  int priority;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// A [Repeat] rule as text, or null for a task that happens once. Kept
/// as text so a rule from a newer version travels through this one and
/// through the server intact instead of being dropped.
@override final  String? repeat;
@override final  String? deletedAt;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCopyWith<_Task> get copyWith => __$TaskCopyWithImpl<_Task>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Task&&(identical(other.id, id) || other.id == id)&&(identical(other.listId, listId) || other.listId == listId)&&(identical(other.title, title) || other.title == title)&&(identical(other.sortKey, sortKey) || other.sortKey == sortKey)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.done, done) || other.done == done)&&(identical(other.doneAt, doneAt) || other.doneAt == doneAt)&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt)&&(identical(other.dueHasTime, dueHasTime) || other.dueHasTime == dueHasTime)&&(identical(other.remind, remind) || other.remind == remind)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.repeat, repeat) || other.repeat == repeat)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,listId,title,sortKey,updatedAt,notes,done,doneAt,dueAt,dueHasTime,remind,priority,const DeepCollectionEquality().hash(_tags),repeat,deletedAt);
}

@override
String toString() {
    return 'Task(id: $id, listId: $listId, title: $title, sortKey: $sortKey, updatedAt: $updatedAt, notes: $notes, done: $done, doneAt: $doneAt, dueAt: $dueAt, dueHasTime: $dueHasTime, remind: $remind, priority: $priority, tags: $tags, repeat: $repeat, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$TaskCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$TaskCopyWith(_Task value, $Res Function(_Task) _then) = __$TaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String listId, String title, String sortKey, String updatedAt, String notes, bool done, int? doneAt, int? dueAt, bool dueHasTime, bool remind, int priority, List<String> tags, String? repeat, String? deletedAt
});




}
/// @nodoc
class __$TaskCopyWithImpl<$Res>
    implements _$TaskCopyWith<$Res> {
  __$TaskCopyWithImpl(this._self, this._then);

  final _Task _self;
  final $Res Function(_Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? listId = null,Object? title = null,Object? sortKey = null,Object? updatedAt = null,Object? notes = null,Object? done = null,Object? doneAt = freezed,Object? dueAt = freezed,Object? dueHasTime = null,Object? remind = null,Object? priority = null,Object? tags = null,Object? repeat = freezed,Object? deletedAt = freezed,}) {
  return _then(_Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,listId: null == listId ? _self.listId : listId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,sortKey: null == sortKey ? _self.sortKey : sortKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,doneAt: freezed == doneAt ? _self.doneAt : doneAt // ignore: cast_nullable_to_non_nullable
as int?,dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as int?,dueHasTime: null == dueHasTime ? _self.dueHasTime : dueHasTime // ignore: cast_nullable_to_non_nullable
as bool,remind: null == remind ? _self.remind : remind // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,repeat: freezed == repeat ? _self.repeat : repeat // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
