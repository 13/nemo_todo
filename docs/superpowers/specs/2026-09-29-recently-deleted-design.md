# Recently deleted

## Goal

Deleting a task shows an undo for a few seconds, and after that the task
is gone as far as anyone can see -- although every device and the server
still hold it as a tombstone. Put those tombstones to use: a "Recently
deleted" page lists the lists and tasks deleted in the last 30 days,
newest first, and brings any of them back, or deletes one for good at
once.

## Decisions

| Topic | Decision |
|---|---|
| What is listed | Lists and tasks tombstoned in the last 30 days, newest deletion first |
| Including | Tasks that went down with a list not offered back (see below) |
| Restore | A normal edit: `deleted_at` cleared, fresh HLC, synced like any change |
| Restored into | Its own list, or the Inbox when that list is deleted or gone |
| Comes back with it | Subtasks deleted with it; its text, tags, dates, photos and what it took were never removed |
| Delete now | Text cleared, tombstone stamped at the epoch with a fresh HLC; the next purge takes it |
| Merge rules | Unchanged: last write wins already allows un-deleting; now pinned by tests |
| The window | 30 days, one constant in `nemo_core`, shared by the app's view and the server's purge |
| Server purge | Refuses a window under 30 days, in the service and on the command line |
| Where | Settings -> Your data in the nemo and Material looks; under My Lists in the macOS look |
| Lists | Listed when someone deleted them and this account owns them (see below) |

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

The first version left lists out, on the grounds that a list tombstone
could not be told apart from the second Inbox that folding duplicate
Inboxes away leaves behind (`ListsRepository._mergeInboxes`). That was
half true. Nobody can delete an Inbox -- `ListsRepository.delete` refuses
one, and no menu offers it -- so the `is_inbox` flag would have told the
two apart, except that folding cleared it on the tombstone. It no longer
does: a folded Inbox keeps `is_inbox` in its grave, and every query for
the Inbox, in this version and all before it, asks for a live one. No
schema change.

Tombstones folded by an older version have the flag cleared, but keep the
Inbox's icon, `inbox`, which the list editor offers no other list. So
`ListsRepository.isFoldedInbox` is `isInbox || icon == 'inbox'`. The one
case it misses is an Inbox whose icon was changed before an older version
folded it; that comes back as a list called Inbox -- a nuisance, not a
loss. Folding now also moves the extra Inbox's notes across, as it
always moved the tasks, so hiding a folded Inbox hides nothing in it.

A list is offered back when:

- it was deleted within the window,
- it is not a folded Inbox, and
- this account owns it: its role in the sharing the server last reported
  is owner, or none has been reported (a list only this device knows).

A shared list someone else owns and deleted is theirs to bring back: the
server takes a list row from its owner only, and would reject the
restore. Its tasks are still listed one by one, and go back to the
Inbox, as before.

The tasks that went down with an offered list -- same deletion stamp --
are part of it, shown as a count on its row rather than listed beside it.
Tasks deleted from the list earlier keep their own rows; while the list
is deleted they would go back to the Inbox, and once it is restored they
go back into it.

**Restore** is `ListsRepository.restore`, which the undo already used:
the list, and the tasks, subtasks and notes carrying its deletion stamp,
each written again with `deleted_at` cleared and a fresh stamp, queued
and synced as ordinary edits; reminders are rescheduled. Sharing needs
nothing more: the server keeps a list's memberships while it is deleted
(only the purge removes them), and relays the restored rows to everyone
still on it, so a shared list comes back shared with the same people.
`server/test/e2e_sync_test.dart` pins that.

**Delete now** writes the list once more with its name cleared and the
epoch deletion stamp, and erases every task and note in it the way a
task is erased -- text cleared, epoch stamp, subtasks and photos along
with it, a photo's bytes gone from this device when nothing else names
them. Every one, not only those deleted with it, because the server's
purge takes all of a purged list's rows whatever their state, so a task
deleted from it earlier would vanish at the next purge anyway.

## Where it is reached

- **nemo** and **Material**: a "Recently deleted" row in Settings, in the
  "Your data" group beside export and import -- where Android's own apps
  keep their bins.
- **macOS**: under My Lists, the way Notes and Reminders keep theirs: a
  row at the end of the sidebar's lists on a Mac window, and a row under
  the list cards on the Lists page on a phone.

## The page

`RecentlyDeletedScreen` at `/settings/recently-deleted`:

- a line saying lists and tasks stay 30 days;
- when there are deleted lists, a "Lists" heading over one row per list
  -- its name, "Deleted <date>" and how many tasks come back with it --
  then a "Tasks" heading over the tasks;
- one row per task: its title, "Deleted <date>" and the list it goes back
  to, or "Goes back to the Inbox"; Restore and Delete now as buttons with
  names a screen reader says, on a list's row too;
- restoring shows "Task restored" (or "... to the Inbox"), or "List
  restored"; deleting a list for good asks first, naming everything in
  it;
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
deletes one for good after asking; it lists a deleted list with the
count of its tasks and not those tasks, restores it with them, and
deletes it for good after asking.

**Lists.** A folded Inbox is not offered, flagged or (from an older
version) by its icon; nor is a list another account owns, nor one past
the window; restoring a list brings back the tasks, subtasks and notes
deleted with it and not a task deleted before; delete now erases the
list, its tasks and notes and their photos. Folding keeps the flag and
moves notes. End to end, a shared list its owner deletes and restores is
back for the other member.

## Out of scope

- Deleted notes, subtasks deleted on their own, and photos removed from a
  task.
- Restoring a shared list someone else owns and deleted.
- Restoring many at once, or emptying the whole page.
- A per-server setting for the window.
