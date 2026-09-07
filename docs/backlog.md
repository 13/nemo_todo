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

## Master-detail layout on wide screens
**What.** Task list on the left, task detail on the right above 1200 dp.
**Cost of leaving it.** Desktop users open tasks as full pages.
**What closing it takes.** A two-pane shell variant and duplicated route handling.

## Password reset by e-mail, server push notifications, attachments, home-screen widget, iOS, end-to-end encryption, Postgres
Not planned for the self-hosted single-household use case.
