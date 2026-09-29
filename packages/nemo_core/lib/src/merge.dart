import 'package:nemo_core/src/model/sync_row.dart';
import 'package:nemo_core/src/model/task.dart';
import 'package:nemo_core/src/model/task_list.dart';

/// Last-write-wins: the incoming row replaces [local] only when its HLC is
/// strictly greater. Equal stamps are the same event replayed, so the local
/// row is kept and the operation stays idempotent.
bool incomingWins(SyncRow? local, SyncRow incoming) =>
    local == null || incoming.updatedAt.compareTo(local.updatedAt) > 0;

/// [incoming] with each field named in [omitted] -- JSON keys its push left
/// out -- taken from [stored] instead.
///
/// An app from before a field decodes a row without it and pushes it back
/// without the key; left to last-write-wins, the whole row would replace
/// the stored one and reset the field to its default: a list's sort to
/// Manual, a task's work fields and when it was added to nothing. A key
/// sent as null is a value, not an omission, and still wins.
///
/// Only lists and tasks carry [omitted]; any other row is returned as is.
T keepOmitted<T extends SyncRow>(T incoming, T? stored, Set<String> omitted) {
  if (stored == null || omitted.isEmpty) return incoming;
  Map<String, dynamic> fill(
    Map<String, dynamic> row,
    Map<String, dynamic> held,
  ) => {
    ...row,
    for (final key in omitted)
      if (held.containsKey(key)) key: held[key],
  };
  final Object merged = switch ((incoming, stored)) {
    (final TaskList row, final TaskList held) => TaskList.fromJson(
      fill(row.toJson(), held.toJson()),
    ),
    (final Task row, final Task held) => Task.fromJson(
      fill(row.toJson(), held.toJson()),
    ),
    _ => incoming,
  };
  return merged as T;
}
