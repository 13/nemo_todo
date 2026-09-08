# Backlog

Deliberate omissions from v1. Nothing here is a known defect.

## Repeat rules beyond the four
**What.** Every second week, the last Friday of the month, weekdays only.
**Cost of leaving it.** Anything that is not daily, weekly, monthly or
yearly has to be re-created by hand.
**What closing it takes.** A grammar for the `repeat` column richer than a
rule name, and a picker to match. The column already carries text it does
not interpret, so an older app passes a new rule through untouched.

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
