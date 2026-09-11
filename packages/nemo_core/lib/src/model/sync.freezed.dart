// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
SyncChange _$SyncChangeFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'list':
          return SyncChangeList.fromJson(
            json
          );
                case 'task':
          return SyncChangeTask.fromJson(
            json
          );
                case 'subtask':
          return SyncChangeSubtask.fromJson(
            json
          );
                case 'revoke':
          return SyncChangeRevoke.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'SyncChange',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$SyncChange {



  /// Serializes this SyncChange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncChange);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SyncChange()';
}


}

/// @nodoc
class $SyncChangeCopyWith<$Res>  {
$SyncChangeCopyWith(SyncChange _, $Res Function(SyncChange) __);
}


/// Adds pattern-matching-related methods to [SyncChange].
extension SyncChangePatterns on SyncChange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SyncChangeList value)?  list,TResult Function( SyncChangeTask value)?  task,TResult Function( SyncChangeSubtask value)?  subtask,TResult Function( SyncChangeRevoke value)?  revoke,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SyncChangeList() when list != null:
return list(_that);case SyncChangeTask() when task != null:
return task(_that);case SyncChangeSubtask() when subtask != null:
return subtask(_that);case SyncChangeRevoke() when revoke != null:
return revoke(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SyncChangeList value)  list,required TResult Function( SyncChangeTask value)  task,required TResult Function( SyncChangeSubtask value)  subtask,required TResult Function( SyncChangeRevoke value)  revoke,}){
final _that = this;
switch (_that) {
case SyncChangeList():
return list(_that);case SyncChangeTask():
return task(_that);case SyncChangeSubtask():
return subtask(_that);case SyncChangeRevoke():
return revoke(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SyncChangeList value)?  list,TResult? Function( SyncChangeTask value)?  task,TResult? Function( SyncChangeSubtask value)?  subtask,TResult? Function( SyncChangeRevoke value)?  revoke,}){
final _that = this;
switch (_that) {
case SyncChangeList() when list != null:
return list(_that);case SyncChangeTask() when task != null:
return task(_that);case SyncChangeSubtask() when subtask != null:
return subtask(_that);case SyncChangeRevoke() when revoke != null:
return revoke(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( TaskList row)?  list,TResult Function( Task row)?  task,TResult Function( Subtask row)?  subtask,TResult Function( SyncEntity target,  String id)?  revoke,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SyncChangeList() when list != null:
return list(_that.row);case SyncChangeTask() when task != null:
return task(_that.row);case SyncChangeSubtask() when subtask != null:
return subtask(_that.row);case SyncChangeRevoke() when revoke != null:
return revoke(_that.target,_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( TaskList row)  list,required TResult Function( Task row)  task,required TResult Function( Subtask row)  subtask,required TResult Function( SyncEntity target,  String id)  revoke,}) {final _that = this;
switch (_that) {
case SyncChangeList():
return list(_that.row);case SyncChangeTask():
return task(_that.row);case SyncChangeSubtask():
return subtask(_that.row);case SyncChangeRevoke():
return revoke(_that.target,_that.id);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( TaskList row)?  list,TResult? Function( Task row)?  task,TResult? Function( Subtask row)?  subtask,TResult? Function( SyncEntity target,  String id)?  revoke,}) {final _that = this;
switch (_that) {
case SyncChangeList() when list != null:
return list(_that.row);case SyncChangeTask() when task != null:
return task(_that.row);case SyncChangeSubtask() when subtask != null:
return subtask(_that.row);case SyncChangeRevoke() when revoke != null:
return revoke(_that.target,_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class SyncChangeList extends SyncChange {
  const SyncChangeList(this.row, { String? $type}): $type = $type ?? 'list',super._();
  factory SyncChangeList.fromJson(Map<String, dynamic> json) => _$SyncChangeListFromJson(json);

 final  TaskList row;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncChangeListCopyWith<SyncChangeList> get copyWith => _$SyncChangeListCopyWithImpl<SyncChangeList>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncChangeListToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncChangeList&&(identical(other.row, row) || other.row == row));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,row);
}

@override
String toString() {
    return 'SyncChange.list(row: $row)';
}


}

/// @nodoc
abstract mixin class $SyncChangeListCopyWith<$Res> implements $SyncChangeCopyWith<$Res> {
  factory $SyncChangeListCopyWith(SyncChangeList value, $Res Function(SyncChangeList) _then) = _$SyncChangeListCopyWithImpl;
@useResult
$Res call({
 TaskList row
});


$TaskListCopyWith<$Res> get row;

}
/// @nodoc
class _$SyncChangeListCopyWithImpl<$Res>
    implements $SyncChangeListCopyWith<$Res> {
  _$SyncChangeListCopyWithImpl(this._self, this._then);

  final SyncChangeList _self;
  final $Res Function(SyncChangeList) _then;

/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? row = null,}) {
  return _then(SyncChangeList(
null == row ? _self.row : row // ignore: cast_nullable_to_non_nullable
as TaskList,
  ));
}

/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskListCopyWith<$Res> get row {
  
  return $TaskListCopyWith<$Res>(_self.row, (value) {
    return _then(_self.copyWith(row: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncChangeTask extends SyncChange {
  const SyncChangeTask(this.row, { String? $type}): $type = $type ?? 'task',super._();
  factory SyncChangeTask.fromJson(Map<String, dynamic> json) => _$SyncChangeTaskFromJson(json);

 final  Task row;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncChangeTaskCopyWith<SyncChangeTask> get copyWith => _$SyncChangeTaskCopyWithImpl<SyncChangeTask>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncChangeTaskToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncChangeTask&&(identical(other.row, row) || other.row == row));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,row);
}

@override
String toString() {
    return 'SyncChange.task(row: $row)';
}


}

/// @nodoc
abstract mixin class $SyncChangeTaskCopyWith<$Res> implements $SyncChangeCopyWith<$Res> {
  factory $SyncChangeTaskCopyWith(SyncChangeTask value, $Res Function(SyncChangeTask) _then) = _$SyncChangeTaskCopyWithImpl;
@useResult
$Res call({
 Task row
});


$TaskCopyWith<$Res> get row;

}
/// @nodoc
class _$SyncChangeTaskCopyWithImpl<$Res>
    implements $SyncChangeTaskCopyWith<$Res> {
  _$SyncChangeTaskCopyWithImpl(this._self, this._then);

  final SyncChangeTask _self;
  final $Res Function(SyncChangeTask) _then;

/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? row = null,}) {
  return _then(SyncChangeTask(
null == row ? _self.row : row // ignore: cast_nullable_to_non_nullable
as Task,
  ));
}

/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskCopyWith<$Res> get row {
  
  return $TaskCopyWith<$Res>(_self.row, (value) {
    return _then(_self.copyWith(row: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncChangeSubtask extends SyncChange {
  const SyncChangeSubtask(this.row, { String? $type}): $type = $type ?? 'subtask',super._();
  factory SyncChangeSubtask.fromJson(Map<String, dynamic> json) => _$SyncChangeSubtaskFromJson(json);

 final  Subtask row;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncChangeSubtaskCopyWith<SyncChangeSubtask> get copyWith => _$SyncChangeSubtaskCopyWithImpl<SyncChangeSubtask>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncChangeSubtaskToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncChangeSubtask&&(identical(other.row, row) || other.row == row));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,row);
}

@override
String toString() {
    return 'SyncChange.subtask(row: $row)';
}


}

/// @nodoc
abstract mixin class $SyncChangeSubtaskCopyWith<$Res> implements $SyncChangeCopyWith<$Res> {
  factory $SyncChangeSubtaskCopyWith(SyncChangeSubtask value, $Res Function(SyncChangeSubtask) _then) = _$SyncChangeSubtaskCopyWithImpl;
@useResult
$Res call({
 Subtask row
});


$SubtaskCopyWith<$Res> get row;

}
/// @nodoc
class _$SyncChangeSubtaskCopyWithImpl<$Res>
    implements $SyncChangeSubtaskCopyWith<$Res> {
  _$SyncChangeSubtaskCopyWithImpl(this._self, this._then);

  final SyncChangeSubtask _self;
  final $Res Function(SyncChangeSubtask) _then;

/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? row = null,}) {
  return _then(SyncChangeSubtask(
null == row ? _self.row : row // ignore: cast_nullable_to_non_nullable
as Subtask,
  ));
}

/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubtaskCopyWith<$Res> get row {
  
  return $SubtaskCopyWith<$Res>(_self.row, (value) {
    return _then(_self.copyWith(row: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncChangeRevoke extends SyncChange {
  const SyncChangeRevoke({required this.target, required this.id,  String? $type}): $type = $type ?? 'revoke',super._();
  factory SyncChangeRevoke.fromJson(Map<String, dynamic> json) => _$SyncChangeRevokeFromJson(json);

 final  SyncEntity target;
 final  String id;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncChangeRevokeCopyWith<SyncChangeRevoke> get copyWith => _$SyncChangeRevokeCopyWithImpl<SyncChangeRevoke>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncChangeRevokeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncChangeRevoke&&(identical(other.target, target) || other.target == target)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,target,id);
}

@override
String toString() {
    return 'SyncChange.revoke(target: $target, id: $id)';
}


}

/// @nodoc
abstract mixin class $SyncChangeRevokeCopyWith<$Res> implements $SyncChangeCopyWith<$Res> {
  factory $SyncChangeRevokeCopyWith(SyncChangeRevoke value, $Res Function(SyncChangeRevoke) _then) = _$SyncChangeRevokeCopyWithImpl;
@useResult
$Res call({
 SyncEntity target, String id
});




}
/// @nodoc
class _$SyncChangeRevokeCopyWithImpl<$Res>
    implements $SyncChangeRevokeCopyWith<$Res> {
  _$SyncChangeRevokeCopyWithImpl(this._self, this._then);

  final SyncChangeRevoke _self;
  final $Res Function(SyncChangeRevoke) _then;

/// Create a copy of SyncChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? id = null,}) {
  return _then(SyncChangeRevoke(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as SyncEntity,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SyncRequest {

 int get cursor; List<SyncChange> get changes;
/// Create a copy of SyncRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncRequestCopyWith<SyncRequest> get copyWith => _$SyncRequestCopyWithImpl<SyncRequest>(this as SyncRequest, _$identity);

  /// Serializes this SyncRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SyncRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncRequest&&(identical(other.cursor, _this.cursor) || other.cursor == _this.cursor)&&const DeepCollectionEquality().equals(other.changes, _this.changes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SyncRequest;
  return Object.hash(runtimeType,_this.cursor,const DeepCollectionEquality().hash(_this.changes));
}

@override
String toString() {
  final _this = this as SyncRequest;
  return 'SyncRequest(cursor: ${_this.cursor}, changes: ${_this.changes})';
}


}

/// @nodoc
abstract mixin class $SyncRequestCopyWith<$Res>  {
  factory $SyncRequestCopyWith(SyncRequest value, $Res Function(SyncRequest) _then) = _$SyncRequestCopyWithImpl;
@useResult
$Res call({
 int cursor, List<SyncChange> changes
});




}
/// @nodoc
class _$SyncRequestCopyWithImpl<$Res>
    implements $SyncRequestCopyWith<$Res> {
  _$SyncRequestCopyWithImpl(this._self, this._then);

  final SyncRequest _self;
  final $Res Function(SyncRequest) _then;

/// Create a copy of SyncRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cursor = null,Object? changes = null,}) {
  return _then(SyncRequest(
cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,changes: null == changes ? _self.changes : changes // ignore: cast_nullable_to_non_nullable
as List<SyncChange>,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncRequest].
extension SyncRequestPatterns on SyncRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncRequest value)  $default,){
final _that = this;
switch (_that) {
case _SyncRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncRequest value)?  $default,){
final _that = this;
switch (_that) {
case _SyncRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int cursor,  List<SyncChange> changes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncRequest() when $default != null:
return $default(_that.cursor,_that.changes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int cursor,  List<SyncChange> changes)  $default,) {final _that = this;
switch (_that) {
case _SyncRequest():
return $default(_that.cursor,_that.changes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int cursor,  List<SyncChange> changes)?  $default,) {final _that = this;
switch (_that) {
case _SyncRequest() when $default != null:
return $default(_that.cursor,_that.changes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncRequest implements SyncRequest {
  const _SyncRequest({required this.cursor,  List<SyncChange> changes = const <SyncChange>[]}): _changes = changes;
  factory _SyncRequest.fromJson(Map<String, dynamic> json) => _$SyncRequestFromJson(json);

@override final  int cursor;
 final  List<SyncChange> _changes;
@override@JsonKey() List<SyncChange> get changes {
  if (_changes is EqualUnmodifiableListView) return _changes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changes);
}


/// Create a copy of SyncRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncRequestCopyWith<_SyncRequest> get copyWith => __$SyncRequestCopyWithImpl<_SyncRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncRequest&&(identical(other.cursor, cursor) || other.cursor == cursor)&&const DeepCollectionEquality().equals(other.changes, _changes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,cursor,const DeepCollectionEquality().hash(_changes));
}

@override
String toString() {
    return 'SyncRequest(cursor: $cursor, changes: $changes)';
}


}

/// @nodoc
abstract mixin class _$SyncRequestCopyWith<$Res> implements $SyncRequestCopyWith<$Res> {
  factory _$SyncRequestCopyWith(_SyncRequest value, $Res Function(_SyncRequest) _then) = __$SyncRequestCopyWithImpl;
@override @useResult
$Res call({
 int cursor, List<SyncChange> changes
});




}
/// @nodoc
class __$SyncRequestCopyWithImpl<$Res>
    implements _$SyncRequestCopyWith<$Res> {
  __$SyncRequestCopyWithImpl(this._self, this._then);

  final _SyncRequest _self;
  final $Res Function(_SyncRequest) _then;

/// Create a copy of SyncRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cursor = null,Object? changes = null,}) {
  return _then(_SyncRequest(
cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,changes: null == changes ? _self._changes : changes // ignore: cast_nullable_to_non_nullable
as List<SyncChange>,
  ));
}


}


/// @nodoc
mixin _$RejectedChange {

 SyncEntity get entity; String get rowId; String get reason;
/// Create a copy of RejectedChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RejectedChangeCopyWith<RejectedChange> get copyWith => _$RejectedChangeCopyWithImpl<RejectedChange>(this as RejectedChange, _$identity);

  /// Serializes this RejectedChange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RejectedChange;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RejectedChange&&(identical(other.entity, _this.entity) || other.entity == _this.entity)&&(identical(other.rowId, _this.rowId) || other.rowId == _this.rowId)&&(identical(other.reason, _this.reason) || other.reason == _this.reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RejectedChange;
  return Object.hash(runtimeType,_this.entity,_this.rowId,_this.reason);
}

@override
String toString() {
  final _this = this as RejectedChange;
  return 'RejectedChange(entity: ${_this.entity}, rowId: ${_this.rowId}, reason: ${_this.reason})';
}


}

/// @nodoc
abstract mixin class $RejectedChangeCopyWith<$Res>  {
  factory $RejectedChangeCopyWith(RejectedChange value, $Res Function(RejectedChange) _then) = _$RejectedChangeCopyWithImpl;
@useResult
$Res call({
 SyncEntity entity, String rowId, String reason
});




}
/// @nodoc
class _$RejectedChangeCopyWithImpl<$Res>
    implements $RejectedChangeCopyWith<$Res> {
  _$RejectedChangeCopyWithImpl(this._self, this._then);

  final RejectedChange _self;
  final $Res Function(RejectedChange) _then;

/// Create a copy of RejectedChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entity = null,Object? rowId = null,Object? reason = null,}) {
  return _then(RejectedChange(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as SyncEntity,rowId: null == rowId ? _self.rowId : rowId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RejectedChange].
extension RejectedChangePatterns on RejectedChange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RejectedChange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RejectedChange() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RejectedChange value)  $default,){
final _that = this;
switch (_that) {
case _RejectedChange():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RejectedChange value)?  $default,){
final _that = this;
switch (_that) {
case _RejectedChange() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SyncEntity entity,  String rowId,  String reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RejectedChange() when $default != null:
return $default(_that.entity,_that.rowId,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SyncEntity entity,  String rowId,  String reason)  $default,) {final _that = this;
switch (_that) {
case _RejectedChange():
return $default(_that.entity,_that.rowId,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SyncEntity entity,  String rowId,  String reason)?  $default,) {final _that = this;
switch (_that) {
case _RejectedChange() when $default != null:
return $default(_that.entity,_that.rowId,_that.reason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RejectedChange implements RejectedChange {
  const _RejectedChange({required this.entity, required this.rowId, required this.reason});
  factory _RejectedChange.fromJson(Map<String, dynamic> json) => _$RejectedChangeFromJson(json);

@override final  SyncEntity entity;
@override final  String rowId;
@override final  String reason;

/// Create a copy of RejectedChange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RejectedChangeCopyWith<_RejectedChange> get copyWith => __$RejectedChangeCopyWithImpl<_RejectedChange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RejectedChangeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RejectedChange&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.rowId, rowId) || other.rowId == rowId)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,entity,rowId,reason);
}

@override
String toString() {
    return 'RejectedChange(entity: $entity, rowId: $rowId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$RejectedChangeCopyWith<$Res> implements $RejectedChangeCopyWith<$Res> {
  factory _$RejectedChangeCopyWith(_RejectedChange value, $Res Function(_RejectedChange) _then) = __$RejectedChangeCopyWithImpl;
@override @useResult
$Res call({
 SyncEntity entity, String rowId, String reason
});




}
/// @nodoc
class __$RejectedChangeCopyWithImpl<$Res>
    implements _$RejectedChangeCopyWith<$Res> {
  __$RejectedChangeCopyWithImpl(this._self, this._then);

  final _RejectedChange _self;
  final $Res Function(_RejectedChange) _then;

/// Create a copy of RejectedChange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? rowId = null,Object? reason = null,}) {
  return _then(_RejectedChange(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as SyncEntity,rowId: null == rowId ? _self.rowId : rowId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ListMember {

 String get username; MemberRole get role;
/// Create a copy of ListMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ListMemberCopyWith<ListMember> get copyWith => _$ListMemberCopyWithImpl<ListMember>(this as ListMember, _$identity);

  /// Serializes this ListMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ListMember;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ListMember&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.role, _this.role) || other.role == _this.role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ListMember;
  return Object.hash(runtimeType,_this.username,_this.role);
}

@override
String toString() {
  final _this = this as ListMember;
  return 'ListMember(username: ${_this.username}, role: ${_this.role})';
}


}

/// @nodoc
abstract mixin class $ListMemberCopyWith<$Res>  {
  factory $ListMemberCopyWith(ListMember value, $Res Function(ListMember) _then) = _$ListMemberCopyWithImpl;
@useResult
$Res call({
 String username, MemberRole role
});




}
/// @nodoc
class _$ListMemberCopyWithImpl<$Res>
    implements $ListMemberCopyWith<$Res> {
  _$ListMemberCopyWithImpl(this._self, this._then);

  final ListMember _self;
  final $Res Function(ListMember) _then;

/// Create a copy of ListMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? username = null,Object? role = null,}) {
  return _then(ListMember(
username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MemberRole,
  ));
}

}


/// Adds pattern-matching-related methods to [ListMember].
extension ListMemberPatterns on ListMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ListMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ListMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ListMember value)  $default,){
final _that = this;
switch (_that) {
case _ListMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ListMember value)?  $default,){
final _that = this;
switch (_that) {
case _ListMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String username,  MemberRole role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ListMember() when $default != null:
return $default(_that.username,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String username,  MemberRole role)  $default,) {final _that = this;
switch (_that) {
case _ListMember():
return $default(_that.username,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String username,  MemberRole role)?  $default,) {final _that = this;
switch (_that) {
case _ListMember() when $default != null:
return $default(_that.username,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ListMember implements ListMember {
  const _ListMember({required this.username, required this.role});
  factory _ListMember.fromJson(Map<String, dynamic> json) => _$ListMemberFromJson(json);

@override final  String username;
@override final  MemberRole role;

/// Create a copy of ListMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ListMemberCopyWith<_ListMember> get copyWith => __$ListMemberCopyWithImpl<_ListMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ListMemberToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ListMember&&(identical(other.username, username) || other.username == username)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,username,role);
}

@override
String toString() {
    return 'ListMember(username: $username, role: $role)';
}


}

/// @nodoc
abstract mixin class _$ListMemberCopyWith<$Res> implements $ListMemberCopyWith<$Res> {
  factory _$ListMemberCopyWith(_ListMember value, $Res Function(_ListMember) _then) = __$ListMemberCopyWithImpl;
@override @useResult
$Res call({
 String username, MemberRole role
});




}
/// @nodoc
class __$ListMemberCopyWithImpl<$Res>
    implements _$ListMemberCopyWith<$Res> {
  __$ListMemberCopyWithImpl(this._self, this._then);

  final _ListMember _self;
  final $Res Function(_ListMember) _then;

/// Create a copy of ListMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? username = null,Object? role = null,}) {
  return _then(_ListMember(
username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MemberRole,
  ));
}


}


/// @nodoc
mixin _$SyncResponse {

 int get cursor; String get serverHlc; List<SyncChange> get changes; List<RejectedChange> get rejected; Map<String, List<ListMember>> get members; bool get hasMore;/// What the server says it is running. Empty from a server old enough
/// not to say, which is not the same as a mismatch.
 String get serverVersion;
/// Create a copy of SyncResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncResponseCopyWith<SyncResponse> get copyWith => _$SyncResponseCopyWithImpl<SyncResponse>(this as SyncResponse, _$identity);

  /// Serializes this SyncResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SyncResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncResponse&&(identical(other.cursor, _this.cursor) || other.cursor == _this.cursor)&&(identical(other.serverHlc, _this.serverHlc) || other.serverHlc == _this.serverHlc)&&const DeepCollectionEquality().equals(other.changes, _this.changes)&&const DeepCollectionEquality().equals(other.rejected, _this.rejected)&&const DeepCollectionEquality().equals(other.members, _this.members)&&(identical(other.hasMore, _this.hasMore) || other.hasMore == _this.hasMore)&&(identical(other.serverVersion, _this.serverVersion) || other.serverVersion == _this.serverVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SyncResponse;
  return Object.hash(runtimeType,_this.cursor,_this.serverHlc,const DeepCollectionEquality().hash(_this.changes),const DeepCollectionEquality().hash(_this.rejected),const DeepCollectionEquality().hash(_this.members),_this.hasMore,_this.serverVersion);
}

@override
String toString() {
  final _this = this as SyncResponse;
  return 'SyncResponse(cursor: ${_this.cursor}, serverHlc: ${_this.serverHlc}, changes: ${_this.changes}, rejected: ${_this.rejected}, members: ${_this.members}, hasMore: ${_this.hasMore}, serverVersion: ${_this.serverVersion})';
}


}

/// @nodoc
abstract mixin class $SyncResponseCopyWith<$Res>  {
  factory $SyncResponseCopyWith(SyncResponse value, $Res Function(SyncResponse) _then) = _$SyncResponseCopyWithImpl;
@useResult
$Res call({
 int cursor, String serverHlc, List<SyncChange> changes, List<RejectedChange> rejected, Map<String, List<ListMember>> members, bool hasMore, String serverVersion
});




}
/// @nodoc
class _$SyncResponseCopyWithImpl<$Res>
    implements $SyncResponseCopyWith<$Res> {
  _$SyncResponseCopyWithImpl(this._self, this._then);

  final SyncResponse _self;
  final $Res Function(SyncResponse) _then;

/// Create a copy of SyncResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cursor = null,Object? serverHlc = null,Object? changes = null,Object? rejected = null,Object? members = null,Object? hasMore = null,Object? serverVersion = null,}) {
  return _then(SyncResponse(
cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,serverHlc: null == serverHlc ? _self.serverHlc : serverHlc // ignore: cast_nullable_to_non_nullable
as String,changes: null == changes ? _self.changes : changes // ignore: cast_nullable_to_non_nullable
as List<SyncChange>,rejected: null == rejected ? _self.rejected : rejected // ignore: cast_nullable_to_non_nullable
as List<RejectedChange>,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as Map<String, List<ListMember>>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,serverVersion: null == serverVersion ? _self.serverVersion : serverVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncResponse].
extension SyncResponsePatterns on SyncResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncResponse value)  $default,){
final _that = this;
switch (_that) {
case _SyncResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncResponse value)?  $default,){
final _that = this;
switch (_that) {
case _SyncResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int cursor,  String serverHlc,  List<SyncChange> changes,  List<RejectedChange> rejected,  Map<String, List<ListMember>> members,  bool hasMore,  String serverVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncResponse() when $default != null:
return $default(_that.cursor,_that.serverHlc,_that.changes,_that.rejected,_that.members,_that.hasMore,_that.serverVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int cursor,  String serverHlc,  List<SyncChange> changes,  List<RejectedChange> rejected,  Map<String, List<ListMember>> members,  bool hasMore,  String serverVersion)  $default,) {final _that = this;
switch (_that) {
case _SyncResponse():
return $default(_that.cursor,_that.serverHlc,_that.changes,_that.rejected,_that.members,_that.hasMore,_that.serverVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int cursor,  String serverHlc,  List<SyncChange> changes,  List<RejectedChange> rejected,  Map<String, List<ListMember>> members,  bool hasMore,  String serverVersion)?  $default,) {final _that = this;
switch (_that) {
case _SyncResponse() when $default != null:
return $default(_that.cursor,_that.serverHlc,_that.changes,_that.rejected,_that.members,_that.hasMore,_that.serverVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncResponse implements SyncResponse {
  const _SyncResponse({required this.cursor, required this.serverHlc,  List<SyncChange> changes = const <SyncChange>[],  List<RejectedChange> rejected = const <RejectedChange>[],  Map<String, List<ListMember>> members = const <String, List<ListMember>>{}, this.hasMore = false, this.serverVersion = ''}): _changes = changes,_rejected = rejected,_members = members;
  factory _SyncResponse.fromJson(Map<String, dynamic> json) => _$SyncResponseFromJson(json);

@override final  int cursor;
@override final  String serverHlc;
 final  List<SyncChange> _changes;
@override@JsonKey() List<SyncChange> get changes {
  if (_changes is EqualUnmodifiableListView) return _changes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changes);
}

 final  List<RejectedChange> _rejected;
@override@JsonKey() List<RejectedChange> get rejected {
  if (_rejected is EqualUnmodifiableListView) return _rejected;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rejected);
}

 final  Map<String, List<ListMember>> _members;
@override@JsonKey() Map<String, List<ListMember>> get members {
  if (_members is EqualUnmodifiableMapView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_members);
}

@override@JsonKey() final  bool hasMore;
/// What the server says it is running. Empty from a server old enough
/// not to say, which is not the same as a mismatch.
@override@JsonKey() final  String serverVersion;

/// Create a copy of SyncResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncResponseCopyWith<_SyncResponse> get copyWith => __$SyncResponseCopyWithImpl<_SyncResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncResponse&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.serverHlc, serverHlc) || other.serverHlc == serverHlc)&&const DeepCollectionEquality().equals(other.changes, _changes)&&const DeepCollectionEquality().equals(other.rejected, _rejected)&&const DeepCollectionEquality().equals(other.members, _members)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.serverVersion, serverVersion) || other.serverVersion == serverVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,cursor,serverHlc,const DeepCollectionEquality().hash(_changes),const DeepCollectionEquality().hash(_rejected),const DeepCollectionEquality().hash(_members),hasMore,serverVersion);
}

@override
String toString() {
    return 'SyncResponse(cursor: $cursor, serverHlc: $serverHlc, changes: $changes, rejected: $rejected, members: $members, hasMore: $hasMore, serverVersion: $serverVersion)';
}


}

/// @nodoc
abstract mixin class _$SyncResponseCopyWith<$Res> implements $SyncResponseCopyWith<$Res> {
  factory _$SyncResponseCopyWith(_SyncResponse value, $Res Function(_SyncResponse) _then) = __$SyncResponseCopyWithImpl;
@override @useResult
$Res call({
 int cursor, String serverHlc, List<SyncChange> changes, List<RejectedChange> rejected, Map<String, List<ListMember>> members, bool hasMore, String serverVersion
});




}
/// @nodoc
class __$SyncResponseCopyWithImpl<$Res>
    implements _$SyncResponseCopyWith<$Res> {
  __$SyncResponseCopyWithImpl(this._self, this._then);

  final _SyncResponse _self;
  final $Res Function(_SyncResponse) _then;

/// Create a copy of SyncResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cursor = null,Object? serverHlc = null,Object? changes = null,Object? rejected = null,Object? members = null,Object? hasMore = null,Object? serverVersion = null,}) {
  return _then(_SyncResponse(
cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,serverHlc: null == serverHlc ? _self.serverHlc : serverHlc // ignore: cast_nullable_to_non_nullable
as String,changes: null == changes ? _self._changes : changes // ignore: cast_nullable_to_non_nullable
as List<SyncChange>,rejected: null == rejected ? _self._rejected : rejected // ignore: cast_nullable_to_non_nullable
as List<RejectedChange>,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as Map<String, List<ListMember>>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,serverVersion: null == serverVersion ? _self.serverVersion : serverVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
