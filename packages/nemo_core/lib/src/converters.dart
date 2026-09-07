import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores a list of strings as a JSON array in a text column.
///
/// Lives here so the app and the server databases, which each define the
/// synced tables, map the `tags` column the same way.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
