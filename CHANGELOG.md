# Changelog

Every released version has a section here, and the release notes on GitHub
are that section verbatim: the release workflow reads it out of this file,
so a version with nothing written here ships with nothing to read.

Headings are `## <version> - <date>`, newest first, and the version matches
the one in `app/pubspec.yaml` without its build number. Entries are grouped
under Added, Changed, Fixed and Removed, and each one says what changed for
someone using the app rather than which file moved.

## Unreleased

### Added

- Tasks can repeat: daily, weekly, monthly or yearly. Completing one puts
  the next occurrence on the list, counted from its due date, with the
  checklist carried over unticked.
- On a window wider than 1200 dp a task opens in a pane beside the list
  instead of covering it.
- A shared list can be handed to another member: they become the owner, you
  stay on as an editor.
- `nemo_server purge` clears out tombstones old enough that every device
  has seen them, without letting an old device resurrect what it purged.
- `nemo_server backup <file>` writes a consistent copy of the database
  while the server keeps running.
- Android notices a newer release on GitHub, shows what changed, downloads
  the build for the device and hands it to the system installer. It checks
  once a day, says nothing when it cannot reach GitHub, and Settings has a
  check you can run yourself.

### Changed

- The server sweeps expired sessions at startup and every six hours instead
  of only noticing one when its own token comes back.

### Fixed

- Live updates from the server are no longer lost when the notification
  arrives split across two reads, which left the app showing stale data
  until something else happened to sync.
- A sync that fails now tries again on its own, backing off from 5 seconds
  to 5 minutes, instead of waiting for an edit or a restart.
- The version in Settings is read from the build rather than written into
  the screen, so it stops claiming 0.1.0 after an update.
- Deleting a list now deletes the tasks in it. They used to stay alive
  behind the hidden list and keep posting their reminders. Restoring the
  list brings them back.

## 0.1.0 - 2026-09-08

First release: the app, the server and the sync between them.

### Added

- Tasks with due dates, reminders, notes, subtasks, tags and four
  priorities, in lists with their own colour and icon.
- Today, Upcoming, per-list and search views, and a quick-add bar on each.
- Works offline from first launch; an account is optional and everything
  already on the device is uploaded when one is connected later.
- Sync with a server you host yourself: last-write-wins on a hybrid logical
  clock, tombstones for deletions, and a live stream that pokes the app when
  something changes elsewhere.
- Lists can be shared with other accounts on the same server.
- The web app, served by the same server, with a navigation rail on wide
  windows in place of the bottom bar.
- Reminders on Android that survive a reboot.
- English, German and Italian.
- A server image with accounts, rate-limited sign-in, a health check and a
  `reset-password` command.
