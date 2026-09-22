import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notes_providers.g.dart';

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

@riverpod
Stream<List<Note>> notesByList(Ref ref, String listId) =>
    ref.watch(notesRepositoryProvider).watchByList(listId);

@riverpod
Stream<List<Note>> allNotes(Ref ref) =>
    ref.watch(notesRepositoryProvider).watchAll();

@riverpod
Stream<Note?> noteById(Ref ref, String id) =>
    ref.watch(notesRepositoryProvider).watch(id);

@riverpod
Stream<List<Note>> noteSearch(Ref ref, String query) =>
    ref.watch(notesRepositoryProvider).search(query);
