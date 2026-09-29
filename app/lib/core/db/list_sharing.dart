import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo_core/nemo_core.dart';

/// The sharing metadata the server reports for each list, kept offline.
extension ListMetaWrites on AppDatabase {
  /// Replaces sharing metadata with what the server reported.
  Future<void> setListMeta(
    Map<String, List<ListMember>> members,
    String myUsername,
  ) => transaction(() async {
    await delete(listMeta).go();
    for (final entry in members.entries) {
      final mine = entry.value
          .where((m) => m.username == myUsername)
          .map((m) => m.role.name)
          .firstOrNull;
      await into(listMeta).insert(
        ListMetaCompanion.insert(
          listId: entry.key,
          myRole: Value(mine),
          membersJson: Value(
            jsonEncode([for (final m in entry.value) m.toJson()]),
          ),
        ),
      );
    }
  });

  Future<void> clearListMeta() => delete(listMeta).go();

  Stream<Map<String, ListSharing>> watchListMeta() => select(listMeta)
      .watch()
      .map((rows) => {for (final r in rows) r.listId: ListSharing.fromRow(r)});
}

/// What we know offline about a list's sharing.
class ListSharing {
  const ListSharing({required this.myRole, required this.members});

  factory ListSharing.fromRow(ListMetaRow row) => ListSharing(
    myRole: MemberRole.values.asNameMap()[row.myRole],
    members: (jsonDecode(row.membersJson) as List<dynamic>)
        .map((e) => ListMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Null while the list has never been reported by a server.
  final MemberRole? myRole;
  final List<ListMember> members;

  bool get isShared => members.length > 1;
  bool get isOwner => myRole == null || myRole == MemberRole.owner;
}
