# Upcoming: a "No date" section

## Goal

Open tasks without a due date are only visible in their own list and in
search. Upcoming gains a last section, "No date", listing them across all
lists, so Upcoming shows everything still to do. UI and one local query;
no model, schema, sync or server change.

## Decisions

| Topic | Decision |
|---|---|
| Where | Last section of Upcoming, after the dated days and "Later" |
| What | Open, undeleted tasks with `dueAt == null` in undeleted lists |
| Order | By list (the lists' own order), then each task's `sortKey` |
| Rows | As on Upcoming: `showList: true`, so each row names its list |
| Collapsible | Header collapses like "Completed"; starts expanded; state remembered per device in `KvStore` (`upcoming.noDateCollapsed`, `'1'`/`'0'`) |
| Empty state | Only when there are no dated and no undated open tasks; new text `upcomingEmpty`: "Nothing planned. Tasks with a date or without one show here." (de/it updated) |
| Today, progress bar | Unchanged: undated tasks stay out of Today |
| Pull to sync | Keeps working (shared `TaskListView`) |

## Components

- `TasksRepository.watchNoDate()` -> `Stream<List<Task>>`: `done == false
  & dueAt IS NULL`, through the existing `_visible` filter (undeleted task
  and list), ordered by the list's `sortKey` then the task's `sortKey`
  (join on lists; check `_visible`'s ordering parameter and extend it if it
  cannot order by a list column).
- `noDateTasksProvider` next to `upcomingTasksProvider` in
  `tasks_providers.dart` (same style: generated `@riverpod` if that file
  uses it -- then run build_runner -- or a plain `StreamProvider`).
- `TaskSection` gains `collapsible` (`bool`, default false), `collapsed`
  and `onToggle`, rendered by `TaskListSlivers` with the same header widget
  "Completed" uses. `UpcomingScreen` passes the no-date section with
  `collapsible: true`, the collapsed state read from a small
  `StreamProvider<bool>` over `KvStore.watch('upcoming.noDateCollapsed')`,
  and `onToggle` writing the flipped value.
- `l.upcomingNoDate`: "No date" / "Ohne Datum" / "Senza data".

## Testing

- Repository: `watchNoDate` includes undated open tasks; excludes done,
  deleted, dated, and tasks in deleted lists; orders by list then task.
- Upcoming screen: the "No date" section is last and lists an undated
  task with its list name; collapsing hides its rows and survives
  reopening the screen; only undated tasks -> no empty state; nothing at
  all -> the new empty text; ticking an undated task off from Upcoming
  completes it (and the celebration pill appears as elsewhere).
