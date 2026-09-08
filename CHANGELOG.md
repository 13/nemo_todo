# Changelog

Every released version has a section here, and the release notes on GitHub
are that section verbatim: the release workflow reads it out of this file,
so a version with nothing written here ships with nothing to read.

Headings are `## <version> - <date>`, newest first, and the version matches
the one in `app/pubspec.yaml` without its build number. Entries are grouped
under Added, Changed, Fixed and Removed, and each one says what changed for
someone using the app rather than which file moved.

## Unreleased

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
