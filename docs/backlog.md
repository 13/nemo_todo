# Backlog

Deliberate omissions from v1. Nothing here is a known defect.

## Recurring tasks
**What.** Repeat rules (daily, weekly, monthly) that spawn the next occurrence on completion.
**Cost of leaving it.** Users re-create routine tasks by hand.
**What closing it takes.** A `repeat` rule column on tasks, a spawn-on-done step in the task repository, sync-safe because the spawned task is a normal new row.

## List ownership transfer
**What.** Hand a shared list to another member.
**Cost of leaving it.** The creator must keep the list forever or recreate it.
**What closing it takes.** A members endpoint that swaps roles and re-logs the list.

## Purge of old tombstones
**What.** Server maintenance command deleting rows tombstoned for more than 30 days and their children.
**Cost of leaving it.** Database and initial pulls grow slowly with deleted data.
**What closing it takes.** A `nemo_server purge` subcommand and a note in the README.

## Smaller Android downloads
**What.** The release APK is one 67 MB file carrying all three ABIs.
**Cost of leaving it.** Every install downloads roughly three times the
native code it can use.
**What closing it takes.** `flutter build apk --split-per-abi` (or an app
bundle) in the release job, and a release page that lists the variants.

## Master-detail layout on wide screens
**What.** Task list on the left, task detail on the right above 1200 dp.
**Cost of leaving it.** Desktop users open tasks as full pages.
**What closing it takes.** A two-pane shell variant and duplicated route handling.

## Secure storage back on the current major
**What.** `flutter_secure_storage` is pinned below 11 because 11.0.0
hardcodes `compileSdk 37`, which Google has not published.
**Cost of leaving it.** The pin has to be revisited once API 37 ships.
**What closing it takes.** Raising the constraint and one Android build.

## Password reset by e-mail, server push notifications, attachments, home-screen widget, iOS, end-to-end encryption, Postgres
Not planned for the self-hosted single-household use case.
