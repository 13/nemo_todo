import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// Tasks: streams for every view, HLC-stamped writes, reminder upkeep.
class TasksRepository {
  TasksRepository(
    this._db,
    this._clock,
    this._newId, {
    required this.reminders,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final HlcClock _clock;
  final String Function() _newId;
  final ReminderScheduler reminders;
  final DateTime Function() _now;

  /// Tasks of one list: open first in manual order, then done ones.
  Stream<List<Task>> watchByList(String listId) =>
      (_db.select(_db.tasks)
            ..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.done),
              (t) => OrderingTerm.asc(t.sortKey),
            ]))
          .watch();

  Stream<Task?> watch(String id) => (_db.select(
    _db.tasks,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  /// Due today or overdue and open, plus tasks completed today.
  Stream<List<Task>> watchToday(DateTime now) {
    final tomorrow = dayStartMsFrom(now, 1);
    final today = dayStartMs(now);
    return _visible(
      _db.tasks.dueAt.isNotNull() &
          _db.tasks.dueAt.isSmallerThanValue(tomorrow) &
          (_db.tasks.done.equals(false) |
              _db.tasks.doneAt.isBiggerOrEqualValue(today)),
      _dueOrder,
    );
  }

  /// Open tasks due after today.
  Stream<List<Task>> watchUpcoming(DateTime now) => _visible(
    _db.tasks.done.equals(false) &
        _db.tasks.dueAt.isBiggerOrEqualValue(dayStartMsFrom(now, 1)),
    _dueOrder,
  );

  /// Case-insensitive match on title, notes or tags.
  Stream<List<Task>> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return Stream.value(const []);
    final pattern = '%${q.replaceAll('%', r'\%')}%';
    return _visible(
      _db.tasks.title.like(pattern) |
          _db.tasks.notes.like(pattern) |
          _db.tasks.tags.like(pattern),
      [OrderingTerm.asc(_db.tasks.done), OrderingTerm.asc(_db.tasks.title)],
    );
  }

  Stream<int> watchOpenCount(String listId) {
    final count = _db.tasks.id.count();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([count])
      ..where(
        _db.tasks.listId.equals(listId) &
            _db.tasks.done.equals(false) &
            _db.tasks.deletedAt.isNull(),
      );
    return query.watchSingle().map((r) => r.read(count) ?? 0);
  }

  /// Every distinct tag in use, for suggestions.
  Future<List<String>> allTags() async {
    final rows = await (_db.select(
      _db.tasks,
    )..where((t) => t.deletedAt.isNull())).get();
    return {for (final t in rows) ...t.tags}.toList()..sort();
  }

  Future<Task> create({
    required String listId,
    required String title,
    int? dueAt,
    bool dueHasTime = false,
    bool remind = false,
    int priority = 0,
    List<String> tags = const [],
    String notes = '',
    Repeat? repeat,
  }) async {
    final task = Task(
      id: _newId(),
      listId: listId,
      title: title.trim(),
      notes: notes,
      dueAt: dueAt,
      dueHasTime: dueHasTime,
      remind: remind && dueAt != null,
      priority: priority,
      tags: tags,
      // A rule with nothing to count from would never come back.
      repeat: dueAt == null ? null : repeat?.encode(),
      sortKey: await nextSortKey(listId),
      updatedAt: _clock.now().toString(),
    );
    await _write(task);
    return task;
  }

  Future<void> save(Task task) => _write(task);

  Future<void> setDone(String id, {required bool done}) async {
    final task = await _db.taskById(id);
    if (task == null) return;
    await _write(
      task.copyWith(
        done: done,
        doneAt: done ? _now().millisecondsSinceEpoch : null,
      ),
    );
    if (done) await _spawnRepeat(task);
  }

  /// Puts the next occurrence of a repeating task on the list.
  ///
  /// The completed one stays completed and keeps its history; the next one
  /// is an ordinary new row, which is what makes this safe to sync -- two
  /// devices ticking the same task off produce two new tasks rather than a
  /// conflict, and the loser is a duplicate the user can delete rather than
  /// a lost edit.
  ///
  /// A rule needs a due date to count from, and a rule this version does
  /// not recognise is left alone rather than guessed at.
  Future<void> _spawnRepeat(Task task) async {
    final rule = task.repeatRule;
    final dueAt = task.dueAt;
    if (rule == null || dueAt == null) return;

    final next = task.copyWith(
      id: _newId(),
      done: false,
      doneAt: null,
      dueAt: rule.nextDueAt(dueAt: dueAt, after: _now()),
      sortKey: await nextSortKey(task.listId),
      updatedAt: _clock.now().toString(),
    );
    await _write(next);

    // The checklist comes with it, unticked: a weekly shop whose next
    // occurrence arrives already ticked off is not a checklist.
    final subtasks = await (_db.select(
      _db.subtasks,
    )..where((t) => t.taskId.equals(task.id) & t.deletedAt.isNull())).get();
    for (final sub in subtasks) {
      await _db.upsertSubtask(
        sub.copyWith(
          id: _newId(),
          taskId: next.id,
          done: false,
          updatedAt: _clock.now().toString(),
        ),
      );
    }
  }

  Future<void> delete(String id) async {
    final task = await _db.taskById(id);
    if (task == null) return;
    await _write(task.copyWith(deletedAt: _clock.now().toString()));
  }

  Future<void> restore(String id) async {
    final task = await _db.taskById(id);
    if (task == null) return;
    await _write(task.copyWith(deletedAt: null));
  }

  /// Places [id] between its new neighbours; only that row changes.
  Future<void> placeBetween(String id, {String? before, String? after}) async {
    final task = await _db.taskById(id);
    if (task == null) return;
    final prev = before == null ? null : (await _db.taskById(before))?.sortKey;
    final next = after == null ? null : (await _db.taskById(after))?.sortKey;
    if (prev != null && next != null && prev.compareTo(next) >= 0) return;
    await _write(task.copyWith(sortKey: SortKey.between(prev, next)));
  }

  Future<String> nextSortKey(String listId) async {
    final last =
        await (_db.select(_db.tasks)
              ..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    return last == null ? SortKey.first() : SortKey.after(last.sortKey);
  }

  Future<void> _write(Task task) async {
    final stamped = task.copyWith(
      updatedAt: task.deletedAt ?? _clock.now().toString(),
    );
    await _db.upsertTask(stamped);
    await reminders.sync(stamped);
  }

  /// Tasks matching [filter] whose list and self are not deleted.
  Stream<List<Task>> _visible(
    Expression<bool> filter,
    List<OrderingTerm> order,
  ) {
    final query =
        _db.select(_db.tasks).join([
            innerJoin(
              _db.lists,
              _db.lists.id.equalsExp(_db.tasks.listId),
              useColumns: false,
            ),
          ])
          ..where(
            _db.tasks.deletedAt.isNull() &
                _db.lists.deletedAt.isNull() &
                filter,
          )
          ..orderBy(order);
    return query.watch().map(
      (rows) => [for (final r in rows) r.readTable(_db.tasks)],
    );
  }

  List<OrderingTerm> get _dueOrder => [
    OrderingTerm.asc(_db.tasks.done),
    OrderingTerm.asc(_db.tasks.dueAt),
    OrderingTerm.asc(_db.tasks.sortKey),
  ];
}
