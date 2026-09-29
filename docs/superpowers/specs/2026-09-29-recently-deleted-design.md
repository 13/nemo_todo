# Recently deleted

## Goal

Deleting a task shows an undo for a few seconds, and after that the task
is gone as far as anyone can see -- although every device and the server
still hold it as a tombstone. Put those tombstones to use: a "Recently
deleted" page lists the tasks deleted in the last 30 days, newest first,
and brings any of them back, or deletes one for good at once.

## Decisions

| Topic | Decision |
|---|---|
| What is listed | Tasks tombstoned in the last 30 days, newest deletion first |
| Including | Tasks that went down with their list |
| Restore | A normal edit: `deleted_at` cleared, fresh HLC, synced like any change |
| Restored into | Its own list, or the Inbox when that list is deleted or gone |
| Comes back with it | Subtasks deleted with it; its text, tags, dates, photos and what it took were never removed |
| Delete now | Text cleared, tombstone stamped at the epoch with a fresh HLC; the next purge takes it |
| Merge rules | Unchanged: last write wins already allows un-deleting; now pinned by tests |
| The window | 30 days, one constant in `nemo_core`, shared by the app's view and the server's purge |
| Server purge | Refuses a window under 30 days, in the service and on the command line |
| Where | Settings -> Your data in the nemo and Material looks; under My Lists in the macOS look |
| Lists | Not listed; stated limit (see below) |

## What a deletion leaves behind

`TasksRepository.delete` writes the task again with `deleted_at` set and
`updated_at` equal to it. Nothing cascades: the task's subtasks and photos
stay live rows, hidden because their task is. Deleting a list is the one
cascade -- the list, its tasks, their subtasks and its notes all take the
list's own stamp, which is how `ListsRepository.restore` finds exactly
those rows again.

A tombstone keeps every field. It travels to every device like any other
change and sits in every database until the server's `purge` retires it
and tells devices to drop it (a revoke). A photo row that is not itself
tombstoned keeps its blob on the server, because the blob sweep spares
every hash a photo row still names, tombstoned or not; so a deleted
task's pictures are there to come back for as long as the task is.

## Merge rules

`incomingWins` compares `updated_at` and nothing else; `deleted_at` is
just a field of the row. Un-deleting is therefore already an ordinary
edit: a row with `deleted_at: null` and a newer `updated_at` beats the
tombstone everywhere, and a delete made later still beats that. No
change to `nemo_core`'s merge; new tests pin the three cases the feature
leans on -- a restore beats the tombstone, a later delete beats the
restore, and an erased tombstone (see below) beats both a live copy and
an ordinary tombstone although its `deleted_at` is the oldest of all.

The server's skew guard reads `updated_at` only, so an epoch
`deleted_at` passes it.

## Restore

`RecentlyDeletedRepository.restore(taskId)`:

1. the task gets `deleted_at: null` and a fresh `updated_at`, through the
   same write every edit takes, so it is queued, synced and its reminder
   rescheduled;
2. if its list is deleted or missing, its `list_id` becomes the Inbox's
   and its sort key goes to the end of the Inbox -- the server sees a
   move and revokes it from the old list as it would any move;
3. subtasks whose `deleted_at` equals the task's -- the ones a list
   deletion took down with it -- come back with fresh stamps too.
   Subtasks deleted on their own, before, stay deleted.

Photos need nothing: a deletion never tombstoned them. Their bytes are on
this device, or on the server to fetch, since the server keeps a blob
while a row names it.

## Delete now

A tombstone cannot simply be removed from this device: the row is what
tells the server and every other device, and a row deleted locally is a
row the outbox can no longer push. Instead, "Delete now" writes one last
version of it:

- title, notes, solution and tags cleared, so the text is gone from
  every device at the next sync rather than at the next purge;
- `deleted_at` set to the epoch (`0000000000000-0000-<node>`), which sits
  before any window: the row leaves Recently deleted on every device at
  once, and the next `purge` retires it whatever its `--days`;
- a fresh `updated_at`, so this version wins over the ordinary tombstone
  everywhere;
- its subtasks the same way, and its photos tombstoned at the epoch, with
  the bytes removed from this device when nothing else names them.

The page asks first: this is the one step here that cannot be undone.

## The 30-day window

`tombstoneRetention = Duration(days: 30)` in `nemo_core`, with
`tombstoneCutoff(now)`, the HLC string a tombstone must sort at or after
to still count as recent. The app lists tombstones at or after the
cutoff; the server's purge removes those before it.

`PurgeService` already defaulted to 30 days, but `purge --days 1` was
allowed, and it would have made the page offer tasks back that the
server had already retired -- a restore pushed after that lands as a new
row whose subtasks and photos are gone. So both `PurgeService.purge` and
the `purge` command now refuse a window shorter than 30 days, and the
README says why. A longer window is still allowed; the page simply shows
30 days of it. Blob files are swept on the same window, and a deleted
task's photo rows are purged only with the task, so its pictures last at
least as long as it does.

Clocks: the window is measured on each device's own clock against stamps
from others, so a task can appear or leave a little early or late on a
device whose clock is off. The purge runs on the server's clock. Both
sides counting exactly 30 days leaves no margin for the boundary itself;
that edge -- a restore made in the last minutes of day 30 reaching a
server that purged it a moment earlier -- is accepted rather than
defended: the restored task comes back without the subtasks the purge
took.

## Deleted lists

Not listed. A deleted list would be cheap to restore --
`ListsRepository.restore` exists for the undo -- but a list tombstone
cannot be told apart from the second Inbox that folding duplicate
Inboxes away leaves behind (see `ListsRepository._mergeInboxes`), so a
Lists section would offer back "Inbox" lists nobody deleted. The limit,
stated in the README: a deleted list comes back only through its undo;
after that, its tasks are here one by one and return to the Inbox, and
its notes do not come back.

## Where it is reached

- **nemo** and **Material**: a "Recently deleted" row in Settings, in the
  "Your data" group beside export and import -- where Android's own apps
  keep their bins.
- **macOS**: under My Lists, the way Notes and Reminders keep theirs: a
  row at the end of the sidebar's lists on a Mac window, and a row under
  the list cards on the Lists page on a phone.

## The page

`RecentlyDeletedScreen` at `/settings/recently-deleted`:

- a line saying tasks stay 30 days;
- one row per task: its title, "Deleted <date>" and the list it goes back
  to, or "Goes back to the Inbox"; Restore and Delete now as buttons with
  names a screen reader says;
- restoring shows "Task restored" (or "... to the Inbox");
- empty: "Nothing deleted in the last 30 days".

## Testing

**Core.** The three merge cases above; `tombstoneCutoff` puts a 29-day
tombstone inside and a 31-day and an epoch one outside.

**Server.** Purge refuses a window under 30 days; a longer one is still
honoured; an erased (epoch) tombstone is purged on the next run with its
children; the existing 30-day cases still hold.

**Repository.** The view lists only tombstones inside the window, newest
first, with their list; restore clears the tombstone with a stamp newer
than it and queues it; restore into a deleted list lands in the Inbox at
the end; subtasks deleted with the task come back and ones deleted
before do not; delete now clears the text, backdates the tombstone,
tombstones subtasks and photos and leaves the view.

**Sync.** Two devices through the in-process server
(`server/test/e2e_sync_test.dart`): a task deleted on one and restored on
the other is live on both.

**Widgets, in all three styles.** The page is reached from where the
style puts it, lists a deleted task, restores it into its list, and
deletes one for good after asking.

## Out of scope

- Deleted notes, subtasks deleted on their own, and photos removed from a
  task.
- Restoring many at once, or emptying the whole page.
- A per-server setting for the window.
