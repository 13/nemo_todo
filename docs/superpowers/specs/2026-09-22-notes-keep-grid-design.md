# Notes: Google Keep-style grid

## Goal

Make the notes screen look like Google Keep: a masonry grid of note cards
with a Pinned section on top, instead of list rows grouped under their list.
UI only -- the `Note` model, the database, sync and export do not change.

## Decisions

| Topic | Decision |
|---|---|
| Scope | Notes screen layout only. No note colors, no editor restyle |
| Layout | Masonry (staggered) grid via `flutter_staggered_grid_view`'s `SliverMasonryGrid` |
| Sections | "Pinned" then "Others", Keep-style. When no note is pinned, both labels are hidden and it is one grid. When every note is pinned, only "Pinned" shows |
| List grouping | Removed as headings; each card shows its list's name as a small label at the bottom |
| Order within a section | `updatedAt` descending. `sortKey` is per list, so it orders nothing across lists |
| Columns | 2 below 600 px of available width, 3 from 600 px, 4 from 900 px |
| Width cap | Grid sits in `MaxWidth(maxWidth: 1200)`: the default 720 would never reach 4 columns |
| Card | New `NoteCard`: outlined `Card`, rounded corners, no fill color; title (bold, max 2 lines, omitted when empty), body preview as markdown source (max 10 lines, ellipsis; `notePreviewEmpty` when blank), list-name label, pin icon top-right when pinned |
| Keys | Card keeps `note-tile-<id>` so existing finders work |
| Tap | Opens the note (`Routes.note(id)`), as now |
| Search results | Unchanged: still `NoteTile` rows |
| FAB, empty state | Unchanged |
| Strings | New `notesPinned` ("Pinned") and `notesOthers` ("Others") in `app_en.arb`, `app_de.arb` ("Angeheftet", "Andere"), `app_it.arb` ("Fissate", "Altre") |

## Why this shape

Keep has no per-list grouping; its only split is Pinned / Others. Keeping the
list visible as a label on the card preserves the information the old headings
gave without breaking the grid into many short sections.

The body preview stays markdown source, not rendered, for the reason
`NoteTile` already documents: a heading or image would dominate a card. The
masonry layout lets cards differ in height, so a 10-line cap is enough to give
Keep's varied look without one long note filling the screen.

`flutter_staggered_grid_view` is the standard masonry package and its sliver
is lazy, which a hand-rolled column split is not.

## Components

- `app/lib/features/notes/ui/note_card.dart` -- new. `NoteCard({note, listName})`.
- `app/lib/features/notes/ui/notes_screen.dart` -- body becomes a
  `CustomScrollView`: optional section label sliver, `SliverMasonryGrid` of
  pinned cards, optional label, grid of the rest. A list-id to name map comes
  from `allListsProvider`; a note whose list is missing shows no label.
- `app/pubspec.yaml` -- add `flutter_staggered_grid_view`.
- l10n `.arb` files plus regenerated `app_localizations*.dart`.

## Testing

`app/test/features/notes/notes_screen_test.dart`:

- Pinned and unpinned notes: both labels shown, pinned card appears in the
  Pinned section (above the Others label).
- No pinned notes: neither label shown.
- Each card shows its list's name.
- Order within a section follows `updatedAt` descending.
- Tapping a card opens the note (existing test, still passes via
  `note-tile-<id>`).
- Every note gets a card: the grid is lazy, so the test sets a tall surface
  and counts cards.

A `note_card_test.dart` covers the empty title, empty body and pin icon cases.

## Verification

`flutter analyze` clean, notes and search tests pass, and a look at the web
build at phone and desktop widths.
