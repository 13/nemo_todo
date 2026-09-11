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

- Settings names the server it is talking to, beside this build's own
  version. The web app says so when the page is older than the server --
  a browser can hold one in cache long after the server has moved -- and
  tells you to reload.
- The server reports its version on `/healthz`, which needs no account and
  answers even when the web app will not start:
  `curl -s https://nemo.example/healthz` → `{"status":"ok","version":"0.4.0"}`.

## 0.4.0 - 2026-09-11

### Changed

- The mark is a clownfish rather than a lowercase "n": the launcher icon,
  the splash screen, the favicon, the web app's icon, the status bar icon
  reminders post with, and the mark inside the app.

### Fixed

- Connecting a device that had been used offline to an account that
  already had an Inbox left two of them, and the next launch died with
  `Bad state: Too many elements` behind "nemo cannot open its database" --
  the app would not start again at all. The second Inbox is now folded
  into the first, tasks and all, by the sync that landed it.
- A server certificate the device does not trust could only be reviewed on
  the Connect screen, so one that changed under a working account -- a
  renewal, most ordinarily -- stopped syncing and reported "Offline",
  which was the one thing it was not. Settings now says the certificate is
  not trusted and offers to show it; accepting it runs the sync that
  failed on it.

## 0.3.0 - 2026-09-11

### Added

- Every release publishes the server image to `ghcr.io/13/nemo`, tagged with
  the version, its minor series and `latest`, so running the server is a pull
  rather than a clone and a build.
- Every screen says whether an account is connected, beside the settings
  button: the account's initial when there is one, a way in when there is
  not, and a warning when the session has expired.

### Changed

- The web app asks who you are before it shows anything, and signing out of
  it clears the browser rather than leaving one person's tasks behind for
  the next. The Android app is unchanged: an account is still optional,
  and signing out keeps your tasks on the device.

### Fixed

- Android can reach a server whose certificate comes from a certificate
  authority of your own. Dart's HTTP client reads only the system
  certificate store, so an authority installed on the device was invisible
  to it and every connection failed as "could not reach the server". The
  app now shows the certificate the server offered -- who issued it, how
  long it is good for, and its SHA-256 fingerprint -- and asks. What you
  accept is pinned to that certificate on that host; a renewed one asks
  again.

## 0.2.0 - 2026-09-11

### Added

- Tasks can repeat: daily, on weekdays, weekly, every two weeks, monthly,
  on the last weekday of the month, or yearly. Completing one puts the next
  occurrence on the list, counted from its due date, with the checklist
  carried over unticked.
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

- Android session storage is back on the current major version of
  `flutter_secure_storage`, now that the API level it needs exists.
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
