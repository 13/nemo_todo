# Upcoming No Date Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upcoming ends with a collapsible "No date" section listing every open undated task across lists.

**Architecture:** A new `TasksRepository.watchNoDate()` query and a generated `noDateTasksProvider`; `TaskSection` becomes optionally collapsible; `UpcomingScreen` adds the section and remembers its collapsed state in `KvStore`. Spec: `docs/superpowers/specs/2026-09-24-upcoming-no-date-design.md`.

**Tech Stack:** Flutter 3.47 (fvm), Riverpod with riverpod_generator (run build_runner), drift, flutter_test with `pumpApp`.

## Global Constraints

- No change to models, schema, sync or server. Today and its progress bar are unchanged.
- "No date" = open (`done == false`), undeleted tasks with `dueAt == null` in undeleted lists; ordered by the list's `sortKey`, then the task's `sortKey`.
- The section is the last one on Upcoming, titled `upcomingNoDate` ("No date" / "Ohne Datum" / "Senza data"), rows show their list (`showList: true`).
- Collapsible, expanded by default, state in `KvStore` key `upcoming.noDateCollapsed` (`'1'` collapsed / `'0'`).
- Upcoming's empty state only when both dated and undated are empty; `upcomingEmpty` becomes "Nothing planned. Tasks with a date or without one show here." (de: "Nichts geplant. Aufgaben mit oder ohne Datum erscheinen hier."; it: "Niente in programma. Qui compaiono le attività con o senza data.").
- Toolchain: `export PATH=~/fvm/versions/3.47.2/bin:$PATH`, from `app/`; codegen `dart run build_runner build --delete-conflicting-outputs`; `flutter test --concurrency=2` on a directory or single file, one process at a time, 600 s timeout.
- Commit trailer: exactly the two lines in the common rules file (Opus 5.5 (1M context) + Claude-Session), never another model name.
- Branch `feat/upcoming-no-date` (checked out, spec committed).

---

### Task 1: Query and provider

**Files:**
- Modify: `app/lib/features/tasks/data/tasks_repository.dart`
- Modify: `app/lib/features/tasks/ui/tasks_providers.dart` (+ regenerated `tasks_providers.g.dart`)
- Test: the repository's existing test file under `app/test/features/tasks/` (find with `grep -rln "watchUpcoming" app/test`)

**Interfaces:**
- Produces: `Stream<List<Task>> TasksRepository.watchNoDate()`; generated `noDateTasksProvider` (`Stream<List<Task>>`).

- [ ] **Step 1: Failing test** (in the file that tests `watchUpcoming`, using its setup):

```dart
  test('watchNoDate lists open undated tasks by list, then order', () async {
    // Two lists: A (earlier sortKey) and B. Use the file's helpers to
    // create them; if it only has an inbox, create a second list through
    // ListsRepository as the file does elsewhere.
    // Tasks:
    //  B: 'b1' undated open
    //  A: 'a1' undated open, 'a2' undated open (after a1), 'a3' undated done,
    //     'a4' dated open, 'a5' undated open then deleted
    //  C (a list then deleted): 'c1' undated open
    final ids = [for (final t in await repo.watchNoDate().first) t.title];
    expect(ids, ['a1', 'a2', 'b1']);
  });
```

Write the setup concretely with the file's own list/task creation helpers.

- [ ] **Step 2: Run** the test file -- fails (`watchNoDate` undefined).

- [ ] **Step 3: Implement**

```dart
  /// Open tasks without a due date, grouped by their list's order.
  Stream<List<Task>> watchNoDate() => _visible(
    _db.tasks.done.equals(false) & _db.tasks.dueAt.isNull(),
    [
      OrderingTerm.asc(_db.lists.sortKey),
      OrderingTerm.asc(_db.tasks.sortKey),
    ],
  );
```

(`_visible` already joins `lists`, so ordering by `_db.lists.sortKey` works.) In `tasks_providers.dart`, after `upcomingTasks`:

```dart
@riverpod
Stream<List<Task>> noDateTasks(Ref ref) =>
    ref.watch(tasksRepositoryProvider).watchNoDate();
```

Run `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run** the test file and `test/features/tasks` -- pass. Format, analyze clean.

- [ ] **Step 5: Commit** `feat(app): list open tasks without a due date` (stage the repository, providers, generated file, test).

---

### Task 2: Collapsible section on Upcoming

**Files:**
- Modify: `app/lib/features/tasks/ui/task_list_view.dart` (`TaskSection`, `TaskListSlivers`)
- Modify: `app/lib/features/tasks/ui/upcoming_screen.dart`
- Modify: `app/lib/features/tasks/ui/tasks_providers.dart` only if you put the collapsed-state provider there (a plain `StreamProvider` is fine, no codegen needed)
- Modify: `app/lib/l10n/app_{en,de,it}.arb` (+ `flutter gen-l10n`)
- Test: `app/test/features/tasks/upcoming_screen_test.dart` (create or extend the existing Upcoming test file)

**Interfaces:**
- Consumes: `noDateTasksProvider` (Task 1).
- Produces: `TaskSection({required title, required tasks, color, bool collapsible = false, bool collapsed = false, VoidCallback? onToggle})`; section header key `section-no-date` for the new section (pass a `key` through or key the header by title in the test).

- [ ] **Step 1: l10n.** Add `upcomingNoDate` (en "No date", de "Ohne Datum", it "Senza data"), and change `upcomingEmpty` in all three to the texts in Global Constraints. `flutter gen-l10n`.

- [ ] **Step 2: Failing tests** (with `pumpApp(tester, initialLocation: Routes.upcoming)` and seeding via the repository in `seed:` as other Upcoming/Today tests do):
  - one dated task tomorrow and one undated task: the "No date" header appears after the dated section, the undated task's title is under it (compare vertical positions with `tester.getTopLeft`), and its row shows its list name;
  - only an undated task: no empty state, the section shows;
  - nothing: the new empty text "Nothing planned. Tasks with a date or without one show here.";
  - tap the "No date" header: the undated task disappears; `KvStore` `upcoming.noDateCollapsed` is `'1'`; navigate away and back (`router.go(Routes.today)`, then `Routes.upcoming`): still collapsed; tap again: shown, `'0'`;
  - tick the undated task's checkbox (`DoneCheck` in its row): it leaves the section (done tasks are not listed).

- [ ] **Step 3: Run** -- the new tests fail.

- [ ] **Step 4: Implement**

`TaskSection` gains the three fields. In `_TaskListSliversState.build`, for each section:

```dart
      slivers.add(
        SliverToBoxAdapter(
          child: SectionHeader(
            title: section.title,
            count: section.tasks.length,
            color: section.color,
            collapsed: section.collapsible ? section.collapsed : null,
            onToggle: section.collapsible ? section.onToggle : null,
          ),
        ),
      );
      if (section.collapsible && section.collapsed) continue;
      slivers.add(...existing list sliver...);
```

Check `SectionHeader`'s parameters (`app/lib/core/widgets/section_header.dart`): pass `collapsed`/`onToggle` the way the Completed header does; if `collapsed` is non-nullable, only pass it for collapsible sections.

`UpcomingScreen`: watch `noDateTasksProvider` alongside `upcomingTasksProvider` (show the loading/error body until both have data -- `AsyncBody` takes one value; combine by nesting or by building a record once both `hasValue`). Watch a `StreamProvider<bool>` over `ref.watch(kvStoreProvider).watch('upcoming.noDateCollapsed').map((v) => v == '1')` (define it in `upcoming_screen.dart` or `tasks_providers.dart`). Empty state when both lists are empty. Append:

```dart
            TaskSection(
              title: l.upcomingNoDate,
              tasks: noDate,
              collapsible: true,
              collapsed: collapsed,
              onToggle: () => ref
                  .read(kvStoreProvider)
                  .set('upcoming.noDateCollapsed', collapsed ? '0' : '1'),
            ),
```

- [ ] **Step 5: Run** `test/features/tasks`, `test/features/sync` -- pass. Format, analyze clean.

- [ ] **Step 6: Commit** `feat(app): show tasks without a due date at the end of Upcoming`.

---

### Task 3: Changelog and verification

- [ ] **Step 1:** `CHANGELOG.md`: under the existing `## Unreleased` (pull to sync is already there), in its `### Added`, add:

```markdown
- Upcoming ends with a "No date" section: every open task without a due
  date, from all lists. Collapse it with its header; the app remembers.
```

- [ ] **Step 2:** One at a time: `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --concurrency=2 --exclude-tags design` -- clean, all pass.

- [ ] **Step 3:** Commit `docs: No date in Upcoming in the changelog`.
