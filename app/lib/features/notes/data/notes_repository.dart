import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo_core/nemo_core.dart';

/// Notes: streams for the screens, HLC-stamped writes.
class NotesRepository {
  NotesRepository(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final HlcClock _clock;
  final String Function() _newId;

  static List<OrderingTerm Function($NotesTable)> get _order => [
    (t) => OrderingTerm.desc(t.pinned),
    (t) => OrderingTerm.asc(t.sortKey),
  ];

  Stream<List<Note>> watchByList(String listId) =>
      (_db.select(_db.notes)
            ..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())
            ..orderBy(_order))
          .watch();

  Stream<List<Note>> watchAll() => _visible(const Constant(true), _joinOrder);

  Stream<Note?> watch(String id) => (_db.select(
    _db.notes,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  /// Case-insensitive match on title or body.
  Stream<List<Note>> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return Stream.value(const []);
    final pattern = '%${q.replaceAll('%', r'\%')}%';
    return _visible(
      _db.notes.title.like(pattern) | _db.notes.body.like(pattern),
      _joinOrder,
    );
  }

  Future<Note> create({
    required String listId,
    required String title,
    String body = '',
  }) async {
    final note = Note(
      id: _newId(),
      listId: listId,
      title: title.trim(),
      body: body,
      sortKey: await _nextSortKey(listId),
      updatedAt: _clock.now().toString(),
    );
    await _write(note);
    return note;
  }

  Future<void> save(Note note) => _write(note);

  Future<void> setPinned(String id, {required bool pinned}) =>
      _edit(id, (note) => note.copyWith(pinned: pinned));

  Future<void> moveToList(String id, String listId) =>
      _edit(id, (note) => note.copyWith(listId: listId));

  Future<void> delete(String id) =>
      _edit(id, (note) => note.copyWith(deletedAt: _clock.now().toString()));

  Future<void> restore(String id) =>
      _edit(id, (note) => note.copyWith(deletedAt: null));

  Future<void> _edit(String id, Note Function(Note) change) async {
    final note = await _db.noteById(id);
    if (note == null) return;
    await _write(change(note));
  }

  Future<void> _write(Note note) =>
      _db.upsertNote(note.copyWith(updatedAt: _clock.now().toString()));

  Future<String> _nextSortKey(String listId) async {
    final last =
        await (_db.select(_db.notes)
              ..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    return last == null ? SortKey.first() : SortKey.after(last.sortKey);
  }

  /// Notes matching [filter] whose list and self are not deleted.
  ///
  /// A note outlives its list until told otherwise, so without this join a
  /// deleted list's notes would go on surfacing here forever. The mirror of
  /// `TasksRepository._visible`; `watchByList` needs no join because its
  /// caller already knows the list it is asking about is live.
  Stream<List<Note>> _visible(
    Expression<bool> filter,
    List<OrderingTerm> order,
  ) {
    final query =
        _db.select(_db.notes).join([
            innerJoin(
              _db.lists,
              _db.lists.id.equalsExp(_db.notes.listId),
              useColumns: false,
            ),
          ])
          ..where(
            _db.notes.deletedAt.isNull() &
                _db.lists.deletedAt.isNull() &
                filter,
          )
          ..orderBy(order);
    return query.watch().map(
      (rows) => [for (final r in rows) r.readTable(_db.notes)],
    );
  }

  List<OrderingTerm> get _joinOrder => [
    OrderingTerm.desc(_db.notes.pinned),
    OrderingTerm.asc(_db.notes.sortKey),
  ];
}
