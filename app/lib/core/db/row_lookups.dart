import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo_core/nemo_core.dart';

/// Single rows, and the rows hanging on one parent, by id.
extension RowLookups on AppDatabase {
  Future<TaskList?> listById(String id) =>
      (select(lists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Task?> taskById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Subtask?> subtaskById(String id) =>
      (select(subtasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Photo?> photoById(String id) =>
      (select(photos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Photo>> photosOfParent(PhotoParent kind, String id) =>
      (select(photos)..where(
            (t) => t.parentKind.equalsValue(kind) & t.parentId.equals(id),
          ))
          .get();

  Future<Note?> noteById(String id) =>
      (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Note>> notesOfList(String listId) =>
      (select(notes)..where((t) => t.listId.equals(listId))).get();
}
