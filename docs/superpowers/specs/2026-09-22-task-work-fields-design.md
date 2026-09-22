# What a task cost you

## Goal

A task should be able to record what it took: how it was solved, how long
it took, and what it cost. Three optional fields on the task itself, kept
out of the way until someone fills one in, and synced like everything
else.

## Decisions

| Topic | Decision |
|---|---|
| Shape | Three optional fields on `Task`, not a new entity |
| Fields | `solution` (free text), `timeSpentMinutes`, `costMinor` |
| Time | Whole minutes; typed as `90`, `1h 30` or `1:30` |
| Money | Integer minor units; typed as a locale-formatted decimal |
| Currency | One ISO code in Settings, device-local like every other setting |
| Old clients | Accepted loss: an app from before this drops the three on push |
| Where | A section on the task page, collapsed while all three are empty |
| When | Any time, not only once the task is done |

## Why this shape

A task that records its own cost is still a task. Nothing here needs a
lifecycle of its own, a parent, or an order, which is what would justify
a new synced entity — so these are three columns, and everything the
sync already does for a task does the right thing for them for free.

Time and money are stored as integers, minutes and minor units, because
the alternative is a decimal that sync, export and SQLite each round
differently. Parsing happens once, at the edge, where a person types;
everything behind that is exact.

`solution` defaults to empty rather than being nullable, matching `notes`
directly above it, so no use site needs a null check. Time and cost are
nullable, because zero is a real answer for both: a task that cost
nothing is not the same as a task nobody recorded a cost for, and a list
that treats the two alike would quietly turn every blank into a zero.

## What this costs an older client

There is no capability flag. An app released before this change reads a
task with a solution perfectly well — it ignores the keys it does not
know — but when it *edits* that task, its push carries no solution, no
minutes and no cost, and row-level last-write-wins overwrites all three
with nothing.

That is accepted rather than defended. The household is small and
upgrades together, the window is one app update wide, and the failure is
visible and recoverable: the text was typed once and can be typed again.
The alternatives — a fourth capability flag, or a server that merges
absent fields — both cost more than what they protect here, and the
second one cannot tell "I do not know this field" from "I cleared it".

## Model

`packages/nemo_core/lib/src/model/task.dart`, beside `notes`:

```dart
/// How the task was solved, in the person's own words. Empty rather
/// than null, like [notes], so no reader needs a null check.
@Default('') String solution,

/// Whole minutes. Null means nobody recorded a time, which is not the
/// same as recording that it took no time at all.
int? timeSpentMinutes,

/// What it cost, in the minor unit of the currency the app is set to
/// (cents for euro). Integer so the amount survives sync, export and
/// SQLite unrounded. Null means nothing was recorded.
int? costMinor,
```

On the wire: `solution`, `time_spent_minutes`, `cost_minor`.

## The repeating task

`TasksRepository._spawnRepeat` builds the next occurrence with
`copyWith`, so without care a monthly task would arrive carrying last
month's solution, minutes and cost. The next occurrence resets all three:
they describe the occurrence that was completed, not the rule that
produced it. The existing behaviour — the completed one keeps its own
history — is unchanged.

## Storage

Three columns on the identical `Tasks` table in both
`app/lib/core/db/sync_tables.dart` and `server/lib/src/db/sync_tables.dart`:

```dart
TextColumn get solution => text().withDefault(const Constant(''))();
IntColumn get timeSpentMinutes => integer().nullable()();
IntColumn get costMinor => integer().nullable()();
```

App schema 4 → 5, server schema 5 → 6. The migration is three
`addColumn` calls per side and nothing else: the columns are nullable or
defaulted, so every existing row is already valid. Schema snapshots are
re-dumped on both sides, and the step-by-step migration tests cover the
new versions.

## Entering a time and an amount

Two pure functions in `app/lib/utils/`, each with its own tests, because
this is where a typo becomes wrong stored data. `quick_add_parser.dart`
next to them is the precedent: a parser that turns what a person typed
into structured values, tested on its own rather than through a widget.

- `int? parseMinutes(String)` — accepts `90`, `1h 30`, `1h30`, `1:30`,
  `2h`, `45m`. Returns null for empty or unparseable input.
- `int? parseMinorUnits(String, {required String locale})` — accepts
  `12.50`, `12,50`, `12`, using the locale's decimal separator. Returns
  null for empty or unparseable input.

Unparseable input leaves the stored value untouched rather than writing
zero, and the field keeps what was typed so it can be corrected.

Formatting is the inverse: `1 h 30 min` through the l10n catalogue, and
the amount through `NumberFormat.simpleCurrency` from the `intl` package
the app already uses, so a locale that writes `12,50 €` gets that.

## The task page

`TaskWorkSection`, a new widget in
`app/lib/features/tasks/ui/task_work_section.dart`, placed below the
notes field:

- collapsed to one row while all three are empty, so a task that is just
  a task looks exactly as it does today;
- expanded when any of the three is filled, or when the row is tapped;
- solution is a multi-line `TextField` keyed `task-solution`, matching
  the notes field directly above it — the two sit inches apart and should
  behave the same way, which is why this one is not the markdown editor a
  note body uses;
- time and cost are single-line fields keyed `task-time-spent` and
  `task-cost`, each parsed on unfocus;
- saving follows the rule the task page already uses: save on unfocus and
  on pop, never refill a field that has focus.

## Settings

A `currency` entry beside the theme and celebration settings:
`KvKeys.currency` holds an ISO code, defaulted from the device locale the
first time it is read, and a picker offers the common codes. Device-local
like every other setting in this app — there is no synced settings
channel, and inventing one for a display symbol is not worth it. Two
devices set differently disagree only about the symbol drawn beside an
amount that is itself unambiguous.

## Search

`TasksRepository.search` matches `solution` alongside title, notes and
tags, through the shared escaped-LIKE helper in
`app/lib/core/db/like_pattern.dart`.

## Export

No format version bump. The export already writes `Task.toJson`, so the
three fields ride along; a version-3 file simply lacks them and reads
back as the defaults.

## Testing

**Parsers.** `parseMinutes` over `90`, `1h 30`, `1h30`, `1:30`, `2h`,
`45m`, empty and rubbish; `parseMinorUnits` over `12.50`, `12,50`, `12`,
empty and rubbish in at least two locales. Each asserts the exact stored
integer, and rubbish asserts null rather than zero.

**Model.** `Task` JSON round trip carrying all three, and a payload from
before this change reading back as empty and nulls.

**Migration.** Step-by-step tests for app 4 → 5 and server 5 → 6,
asserting an existing task survives with an empty solution and null time
and cost.

**Repeat.** Completing a repeating task that has all three filled spawns
a next occurrence with none of them.

**Search.** A task found by a word that appears only in its solution.

**App.** The section is collapsed when the three are empty and expanded
when one is filled; editing each field stores the parsed value; rubbish
in the time field leaves the stored value alone.

**Export.** A round trip carrying the three fields.

## Out of scope

- Totals: per list, per month, or anywhere else.
- A running timer, or any capture of time other than typing it.
- Reporting or charts over time and cost.
- Multi-currency: one code for the app, not one per amount.
- Who did the work — that needs a member reference and belongs with
  sharing, not here.
