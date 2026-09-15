# Changelog

Every released version has a section here, and the release notes on GitHub
are that section verbatim: the release workflow reads it out of this file,
so a version with nothing written here ships with nothing to read.

Headings are `## <version> - <date>`, newest first, and the version matches
the one in `app/pubspec.yaml` without its build number. Entries are grouped
under Added, Changed, Fixed and Removed, and each one says what changed for
someone using the app rather than which file moved.

Changes not released yet collect under `## Unreleased`, which is renamed to
the version when it is tagged. A new version heading added beside it instead
would ship without them, and nothing would say so.

## 0.9.1 - 2026-09-15

### Fixed

- An import from Settings that fails part way no longer leaves its
  pictures behind on the device.

## 0.9.0 - 2026-09-15

### Added

- Exporting from Settings now includes the photos: the file is a zip with
  the pictures beside the tasks, and importing it brings them back. Exports
  made before still import.

### Fixed

- The achievement banner no longer hides after four seconds for people
  moving through the app with a screen reader or switch access; it waits
  until it is closed.
- An achievement unlocked by a tap can no longer go uncelebrated because a
  sync finished at the same moment.

## 0.8.0 - 2026-09-15

### Added

- Completing a task is celebrated: the check bounces, clearing Today sets
  off confetti, and ten achievements -- from the first task done to a
  30-day streak -- announce themselves as they are unlocked and are listed
  under Settings. An optional sound plays for the big moments.
- Settings has switches for celebrations, their sound and achievements, so
  the app can be kept quiet. They apply to this device only.

### Changed

- The app is called nemo todo on the home screen, in the app switcher, in
  the browser tab and in About. A web app already added to a home screen
  may keep its old label until it is added again.

### Fixed

- On the two days a year the clocks change, Today, Upcoming, quick add's
  "tomorrow" and the count of tasks done on time no longer pick the wrong
  day: a task due late that evening stays in Today, and Upcoming's headings
  name the right dates.

## 0.7.0 - 2026-09-14

### Added

- About in Settings shows the logo, which build this is -- a release, a
  development build from main, or a local one -- with its build number, the
  day it was built and the commit it came from, and the same for the server
  it is connected to.
- Tapping About opens the app's details and the licences of the software it
  is built on.
- "Copy details" puts the app and server versions, commits, build dates and
  platform on the clipboard for a bug report, without the server's address.
- "Source code" opens the project on GitHub.
- The server reports the commit and build date on `/healthz` beside its
  version: `{"status":"ok","version":"0.7.0","commit":"…","builtAt":"…"}`.
- Tapping a tag, on a task in a list or on the task itself, shows every task
  with that tag across all lists.
- A long press on a task in Today, Upcoming, search or a tag moves it to
  today, tomorrow, next week or a picked day, or clears its date, with undo.
  In a list of your own a long press still picks the task up to reorder it.
- Quick add reads the line you type: `Milk #shop !high tomorrow` adds "Milk",
  tagged `shop`, at high priority, due tomorrow. A date word counts only at
  the end, so "Buy the Sunday paper" stays a title; German and Italian date
  and priority words work in those languages.

### Fixed

- Sharing a list sends the photos already on it to the new member. Before,
  someone who had used the app since those photos were added never got them;
  and removing a member now takes the photos off their device along with the
  tasks.

## 0.6.0 - 2026-09-14

### Added

- Photos on tasks: take one or pick one from the device, and it shows in a
  strip on the task and as a thumbnail in the list. Photos reach every device
  and everyone the list is shared with.
- A photo is shrunk to at most 2048 pixels on its longest side before it
  leaves the device, and the location and camera details a phone writes into
  it are removed.
- When the server refuses a photo -- too large, or out of room -- it stays on
  the device marked "not uploaded", with a line saying why.
- The server keeps photos in `NEMO_BLOB_DIR` (default `/data/blobs`), which
  belongs in backups beside the database. An app from before this version
  keeps syncing everything else and shows photos once it is updated; this app
  keeps its photos on the device until an older server is updated too.
- Settings changes your password, which signs out your other devices but
  not the one you are holding.
- Settings deletes your account, once you have typed your password. Lists
  only you use go with it; a shared list you own goes to the member first by
  username, and the others keep working in it. The Android app keeps your
  tasks on the device afterwards, as signing out does. Both need a server
  from this version; everything else still syncs with an older one.
- A "Custom…" repeat: every so many days, weeks, months or years, or a
  weekday of the month such as the second Tuesday.
- Settings exports your lists, tasks and subtasks to a JSON file and imports
  one again. An import adds only what is missing or was deleted, and never
  overwrites a task edited since. Photos are not part of the file.

### Changed

- The mark is a checkmark cut out of a teal disc rather than a clownfish:
  the launcher icon, the splash screen, the favicon, the web app's icon, the
  status bar icon reminders post with, and the mark inside the app.
- A screen reader names each photo on a task -- "Photo 2 of 3" -- instead of
  announcing a button with no name.

## 0.5.0 - 2026-09-11

### Added

- Settings names the server it is talking to, beside this build's own
  version. The web app says so when the page is older than the server --
  a browser can hold one in cache long after the server has moved -- and
  tells you to reload.
- The server reports its version on `/healthz`, which needs no account and
  answers even when the web app will not start:
  `curl -s https://nemo.example/healthz` → `{"status":"ok","version":"0.5.0"}`.

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
