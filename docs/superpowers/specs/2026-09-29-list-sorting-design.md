# Sorting within a list

## Goal

A list's tasks can today only be put in order by hand. Let a list be
sorted instead by due date, priority, title or when a task was added,
with the hand-made order still the default and still there to go back to.

## Decisions

| Topic | Decision |
|---|---|
| Choices | Manual (default), Due date, Priority, Title, Date added |
| Where it lives | On the list row, synced: a shared list sorts alike for everyone |
| Who changes it | The list's owner, like every other list field the server accepts |
| Wire value | Text (`manual`, `due`, `priority`, `title`, `added`), unknown reads as manual |
| Date added | A new `created_at` on the task, set when a task is made |
| Older tasks | No `created_at`: they sort by the time in their last-write stamp |
| Reordering | Only in Manual: drag and its screen-reader actions are off otherwise |
| Showing it | A line above the tasks names the sort, and tapping it changes it |
| Completed | Still a section of its own, last, in the same order as the open ones |
| Other views | Today, Upcoming, tag and search keep the orders they have |
| Old clients | The server keeps a field an older app's push leaves out |

## Synced or device-local

Device-local would cost nothing on the server: one `KvStore` key per list,
no schema change, no migration. It was weighed and not chosen.

The sort is a property of the list more than of the person looking at it.
A shared shopping list sorted by priority on one phone and by hand on the
other is two people looking at different lists and talking past each
other, and one person with a phone and a browser would have to choose the
same sort twice and keep the two in step by hand. The list row already
travels to every member and every device, so a column on it gets there
for nothing more than a migration.

The cost of that column:

- one text column on `lists` in `nemo_core`'s `TaskList`, the app and the
  server, each with a migration and a re-dumped schema snapshot;
- the rule that only an owner may change a list row, which the server
  already enforces. An editor of a shared list is not offered the choice
  -- the menu leaves it out -- rather than being offered one the server
  would reject and the app would then report as a discarded change;
- an older app that edits the list (renames it, recolours it) pushes a
  row without the field. Left to whole-row last-write-wins that would
  read back as Manual and win; instead the server keeps the stored value
  of any key a list or task row leaves out (`keepOmitted` in `nemo_core`).
  This version always sends the key -- Manual as `"task_order": "manual"`
  -- so a missing key can only mean an app that does not know it. The
  same goes for a task's `created_at`.

"Date added" needs a date the task does not carry. Ids are random UUIDs,
the sort key is the hand-made order, and the last-write stamp moves with
every edit. So the task gains `created_at` (UTC milliseconds, nullable),
set by `TasksRepository.create` and by the next occurrence of a repeating
task. A task from before this change has none; it sorts by the time in
its `updated_at` stamp instead, which is the closest thing it has and is
never missing. Nothing is backfilled: a backfill on one device would have
to be pushed to be seen anywhere else, and every device guessing the same
fallback at read time needs no push.

Both columns reset the app's sync cursor on upgrade, for the reason the
work-fields migration gives: a device on the build before this decoded
every list and task it pulled through a `fromJson` that dropped the new
keys, and holds rows without them that it would otherwise never pull
again.

## Orders

`TaskOrder` in `nemo_core`, with `compareTasks(order)` used by the app:

- **Manual** -- the sort key, as today.
- **Due date** -- earliest first, undated last; ties by sort key.
- **Priority** -- high first, none last; ties by due date, then sort key.
- **Title** -- case-insensitive, ties by sort key.
- **Date added** -- newest first, the way a list you keep adding to is
  read; ties by sort key.

Open tasks always come before done ones. The done ones stay in their own
collapsible section and use the same order, so a list sorted by title
shows its completed tasks by title too.

The order is applied in Dart on the list's stream rather than in SQL:
lists are small, the comparators have to agree between a stream and a
test, and one pure function in `nemo_core` is easier to test than five
query variants.

## The list page

- `ListDetailScreen` sorts `tasksByList` by the list's order.
- `TaskListView.reorderable` is true only while the order is Manual. The
  plain sliver it falls back to has no drag listener, so neither a long
  press nor the reorder actions a screen reader offers are there, and a
  long press opens the reschedule sheet as it does in Today.
- When the order is not Manual, the page shows a line above the tasks --
  a sort icon and "Sorted by due date" -- keyed `task-order-banner`.
  Tapping it opens the picker. It is a button to a screen reader.

## The menus

A "Sort by" entry opens a picker with the five choices, the current one
ticked:

- **nemo**: the list page's overflow menu, and the long-press sheet on a
  list card; the picker is a bottom sheet.
- **macOS**: the same overflow menu and the right-click pop-up on a list
  card or a sidebar row; on a Mac window the picker is the panel that
  drops from the top, as every sheet there is.
- **Material**: the same overflow menu and the long-press sheet on a list
  card; the picker is a bottom sheet.

The Inbox has no card menu, but its page menu has the entry.

## Today, Upcoming, tags, search

Unchanged. Today and Upcoming are already in due order, which is the only
order that makes sense for a view defined by due dates; tag and search are
already by title. A choice there would need a device-local setting per
view and would buy little.

## Testing

**Core.** `TaskOrder` parses every wire value and falls back to Manual on
anything else; each comparator orders a crafted set of tasks as described,
including undated, no-priority, mixed-case titles and a task with no
`created_at`; `TaskList` and `Task` JSON round trips carry the new fields,
and a payload from before them reads back as Manual and null.

**Migration.** App 5 → 6 and server 8 → 9 with the repo's
`SchemaVerifier` tests: an existing list comes through as Manual, an
existing task with no `created_at`, and the app's cursor is reset.

**Repository.** `create` stamps `createdAt`; the next occurrence of a
repeating task gets its own; `ListsRepository.setTaskOrder` stamps and
queues the list.

**Widgets, in all three styles.** Choosing a sort from the list menu
reorders the tasks, shows the banner and removes the drag handles'
reorder actions; choosing Manual again brings both back; the banner opens
the picker; an editor of a shared list is not offered the entry.

## Out of scope

- A sort direction toggle. Each order has the direction people expect.
- Grouping (by priority, by date) rather than sorting.
- Sorting Today, Upcoming, tag or search.
- Sorting notes, which have their own pinned-first order.
