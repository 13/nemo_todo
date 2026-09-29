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
would ship without them, and nothing would say so. `tool/release.sh <version>`
does the renaming, and tags only once CI has passed on the release commit.

## Unreleased

### Added

- `nemo_server status` shows whoever hosts the server how big the database
  is, how many accounts, lists, tasks, photo files and signed-in sessions
  it holds, and when `purge` last ran, so a scheduled purge that stopped
  running does not go unnoticed. It is a command only; nothing about it is
  served over HTTP.
- Reminders on the web. A task's reminder and the daily list show up as
  browser notifications while a nemo tab is open; clicking one brings the
  tab forward on the task. With every tab closed nothing arrives, and a
  reminder missed that way is still shown when the page loads within ten
  minutes of it, not later. Settings says whether the browser allows
  notifications and asks for them; the browser is asked only when you
  press Allow or switch a reminder on. They work in desktop browsers;
  phone browsers do not let a page notify.
- Share into nemo on Android. nemo is in the share menu of other apps:
  shared text, a link or pictures open a "New task" sheet with them filled
  in -- a page's title as the title and its link in the notes, a message's
  first line as the title and the rest as notes, pictures as the task's
  photos. The title reads quick add's `#tags`, `!high` and "tomorrow";
  pick a list (the Inbox unless you choose another), change anything, and
  save, or cancel to keep nothing. Pictures are re-encoded on the phone
  like any other photo, so their location and camera details are dropped.
  It works offline and without an account.
- With TalkBack or another screen reader, a task is read out as one row:
  its title, when it is due (or that it is overdue), its priority, list,
  subtasks, tags and photos. Its tick is a checkbox that says whether the
  task is done, and what a swipe, a long press or a right click does --
  mark done, move to another day, delete, show a tag -- is in the row's
  actions menu.
- Folding sections, like Completed, say whether they are open.

### Changed

- Tapping a reminder on Android opens its task rather than just the app.
- The server keeps its count of sign-up and sign-in attempts in its
  database instead of in memory, so restarting it no longer gives someone
  guessing passwords a fresh ten tries a minute.
- Everything you tap on a phone is at least 48 px across, in every look:
  a task's tick, the accent and list colours, the date, priority and list
  chips under the add field, and the section headers that fold. The
  circles and chips look as they did; only the area that takes the tap
  grew. The macOS look's segmented switches in Settings are a little
  taller on a phone; on a Mac's desktop window it keeps its denser rows.
- In the nemo look in light, a list's name under a task is a shade deeper
  where its colour was too pale to read as small text.
- In the macOS look in dark, a filled button and the chosen day in the
  date picker are a deeper blue, so their white text is readable; the
  chosen tile in the Mac sidebar deepens in the same way.

### Fixed

- Buttons that a screen reader announced without a name now have one:
  the search bar and search button in the Material look, clearing a
  search, the colours and icons when editing a list, and the checkboxes
  of subtasks and of a note's checklist. The logo and the confetti are
  skipped rather than read out.
- With the system's text at twice its size, the lists page, a task's
  small facts, the Mac sidebar and the achievements page no longer run
  off the edge or overflow; the list cards grow to fit their names.

## 0.18.0 - 2026-09-29

### Changed

- The Material style now looks like one of Android's own apps rather
  than nemo in other colours: Roboto, large titles that fold into the bar
  as you scroll, filled tonal cards, and switches with a tick when on.
- In the Material style, a task is added from a New task button that
  opens a sheet with the keyboard up, and the sheet closes once the task
  is in; on a wide window the button sits at the top of the rail.
- In the Material style, search is a bar at the top of Today, beside the
  account, and a search button on the other screens; the bottom bar keeps
  Today, Upcoming, Lists and Notes.
- In the Material style, Settings draws each row as a tile of its own
  with its icon on a tonal circle, as Android 16's Settings does, and a
  task's repeat is picked from a sheet of choices.
- On Android, going back follows the back gesture: the page shrinks to
  show where it leads before letting go.
- The Material style gives a light tap under the finger when a task is
  ticked or swiped.

## 0.17.0 - 2026-09-29

### Changed

- The macOS style now looks like a Mac app throughout, not only in its
  colours: Apple's type sizes in Inter, thin-stroked icons, and denser
  rows with the open task in the accent with white on it, as in Finder.
- On a wide window its sidebar is laid out as Reminders': a search field,
  a tile with a count for each of Today, Upcoming, Lists and Notes, and
  every list with its count, a right-click menu and New list at the foot.
  A list's page names it large in its own colour.
- Settings in the macOS style groups its rows into panels as System
  Settings does, with the sections in a sidebar on a wide window.
- In the macOS style on a wide window, sheets drop from the top of the
  window, a date is picked from a calendar beside the button at a single
  click, context menus are compact, alerts are narrow, segmented controls
  have a grey track, and pages change without sliding.
- On a phone the macOS style follows iOS: larger type, pages sliding in
  from the side, a chevron to go back, and green and red swipe actions.

## 0.16.0 - 2026-09-29

### Added

- A choice of style in Settings, beside light and dark: nemo's own, which
  stays the default and looks as it always has; macOS, with plain greys,
  system blue, thin dividers and a floating sidebar on wide windows; and
  Material 3, in the colours of the wallpaper on Android 12 and later.
- An accent colour in Settings, from the list colours, for any style.
  Text on it and in it stays readable whichever is picked.
- A right click on a task, a list or a line of a note opens the menu a
  long press does, and a task's menu also ticks it off and deletes it.
- Keyboard shortcuts: N for a new task, / for search, 1 to 5 for the
  destinations, the arrow keys or J and K through a list with the open task
  marked, Space to tick it off, Delete, Esc, and ? for the full list, which
  Settings also shows on a wide window.

### Changed

- Outside the nemo style a list's colour is on its icon and its name is
  in grey, so a light colour no longer makes small text hard to read.
- Confetti uses the list colours, bright in every style.
- nemo's orange is a shade deeper, so a medium priority flag and orange
  lists show clearly on the light background.
- On Android the launch splash now shows the nemo logo as the app's
  starting screen does, in the app's own colours, so opening the app no
  longer jumps from a white logo on teal to the app.
- The web app's loading screen now uses the theme chosen in Settings
  rather than always the device's, so with the app set to dark on a light
  device, opening it no longer flashes light first.

### Fixed

- On Android the status and navigation bar icons were white over the
  light theme, where they could not be seen; they are now dark there.

## 0.15.4 - 2026-09-29

### Changed

- Opening the web app again is faster, most on a slow connection: each
  version of the app is now kept by the browser for good, so only the
  page itself is checked for a newer one, rather than every file one
  after another. On a slow mobile connection a repeat visit went from
  about 1.6 seconds to 0.5.
- The nemo logo inside the app is now the mark on its own, as the web
  app's loading screen shows it, rather than the mark on a rounded tile.
  On the web the loading screen now hands over to the app without the
  logo jumping. The app's icon is unchanged.

## 0.15.3 - 2026-09-29

### Fixed

- Opening the web app again no longer downloads all of it again: the
  server now answers a browser's check for a newer copy with "unchanged"
  when nothing has changed. Since 0.15.1 every visit was a full download.

### Changed

- The web app loads faster on a first visit over HTTPS: the server now
  sends it brotli-compressed, about a quarter smaller than before.

## 0.15.2 - 2026-09-29

### Fixed

- 0.15.1 was never built or published, because a check failed; this
  release is the first to carry its changes, listed below.

## 0.15.1 - 2026-09-29

### Changed

- The web app shows a loading screen with the nemo logo from the moment
  the page opens, instead of a blank white page until the app is ready.

### Fixed

- The web app loads faster: the server now sends it compressed, which
  cuts a first visit from about 11 MB to about 4 MB, and a browser checks
  for a newer copy of every file after an update instead of possibly
  reusing an old one.

## 0.15.0 - 2026-09-28

### Added

- A daily list: once a day, at a time you choose in Settings, the Android
  app shows one notification with what is due today and what is overdue,
  and opens Today when tapped. Days with nothing due stay quiet. Off until
  you turn it on.

## 0.14.2 - 2026-09-24

### Fixed

- Undo snackbars (after deleting a task, list or note, completing a task
  with a swipe, or moving a task to another day) now go away on their own
  instead of staying on screen until tapped.

## 0.14.1 - 2026-09-24

### Fixed

- 0.14.0 was never built or published, because a check failed; this
  release is the first to carry its changes, listed below.

## 0.14.0 - 2026-09-24

### Added

- Pull down on Today, Upcoming, Lists, a list, a tag, Notes or search
  results to sync straight away when an account is connected. If the
  server cannot be reached, a short message says your changes are saved
  and will sync later.
- Upcoming ends with a "No date" section: every open task without a due
  date, from all lists. Collapse it with its header; the app remembers.
- Selecting text in a note shows a "Make todo" button right above the
  keyboard, and a one-time tip explains it; the read view says once that
  a long-press turns a line into a todo. In the web app, right-clicking
  a note's text now shows the app's menu with "Make todo".

## 0.13.0 - 2026-09-24

### Added

- Ticking a task off now shows a short, varied message: a word of
  encouragement, how far along today is, "one to go", or a note when a
  streak continues. Swiping a task done puts the message in the Undo bar.
- The Today screen shows how many of today's tasks are done, with a calm
  line to start the day, a welcome back after a break, and a note when
  everything is done. Messages follow the Celebrations switch in Settings.

## 0.12.0 - 2026-09-24

### Added

- A note can switch between its markdown and a formatted read view with
  the button in its top right corner; the choice is remembered. In the
  read view checkboxes can be ticked, links open, and tapping the text
  goes back to editing on that line.
- Note text can become a todo: select text or put the cursor on a list
  line and tap the new toolbar button (or Ctrl+Shift+T, Cmd+Shift+T on
  Mac), long-press a line in the read view, or use "Make todo from note"
  at the bottom of a note. Several lines become one task each or one
  task with subtasks. The note keeps its text and links to each task,
  showing whether it is done.

## 0.11.1 - 2026-09-23

### Changed

- Note cards and notes in search results show their text formatted --
  bold, italic, headings, links, bullets and checkboxes -- instead of the
  raw markdown characters.
- The notes screen has the account and settings buttons in its top right
  corner, like every other screen.

## 0.11.0 - 2026-09-23

### Changed

- A note's text is always ready to edit: there is no pencil to tap first.
  Markdown is styled as you type -- bold looks bold, headings are larger,
  struck-through text and ticked checkboxes are struck -- with the markup
  characters drawn faint.
- A note saves a second after you stop typing, as well as when you leave
  it, and a change you did not make never overwrites one that arrived from
  another device. If a save fails, the note says so and keeps your text.

### Added

- A formatting toolbar above the keyboard while you write a note: bold,
  italic, strikethrough, headings, bulleted and numbered lists, checkboxes,
  quotes, code, code blocks, links, undo and redo. With the cursor in a web
  link it can open the link.
- Keyboard shortcuts for notes: Ctrl+B, Ctrl+I, Ctrl+Shift+X and Ctrl+K (Cmd
  on Mac and iOS). Enter in a list starts the next item; Enter on an empty
  item ends the list.

## 0.10.1 - 2026-09-22

### Changed

- Notes show as a grid of cards, the way Google Keep lays them out: pinned
  notes first under their own heading, then the rest, newest first. Each
  card shows more of the note and the name of the list it lives in, and a
  wide screen spreads the grid over up to four columns.

## 0.10.0 - 2026-09-22

### Added

- Notes: a list can hold notes as well as tasks. A note is a title and a
  markdown body, it is shared with the list it lives in, it can carry
  pictures, and it is found by search and carried through export.
- A task can record how it was solved, how long it took and what it cost.
  The three stay out of the way until one is filled in.

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
