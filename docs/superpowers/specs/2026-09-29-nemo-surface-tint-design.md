# Background tint for the nemo style

## Goal

The nemo style's window, surfaces and sidebar are teal-grey whatever
accent is chosen: a pink accent sits on teal-tinted backgrounds. Let the
backgrounds take their tint from the accent instead, and let the tint be
turned down to plain grey or up to something more colourful, in three
steps: None, Subtle, Strong.

## Decisions

| Topic | Decision |
|---|---|
| Levels | `SurfaceTint { none, subtle, strong }` |
| Default | `subtle`: exactly today's colours while no accent is chosen |
| Styles | nemo only; macOS and Material ignore it and do not show the control |
| Hue | The chosen accent's; with no accent, each colour keeps its own (nemo teal) |
| How colours are made | Each surface keeps today's lightness; hue and saturation change |
| Where it is kept | On the device, in the key-value store, like style and accent; not synced |
| Web splash | Unchanged: it knows mode and style, not tint |
| Contrast | `onSurface` and `onSurfaceVariant` stay at 4.5:1 or better on every surface |

## Why lightness is kept

Today's nemo colours were tuned by hand for light and dark: the window is
a touch darker than a card, a separator a touch darker than a container,
text far from all of them. All of that is lightness. Hue and saturation
are only the teal cast. Keeping each colour's HSL lightness and replacing
only its hue and scaling its saturation keeps every one of those
relationships, and so the contrast between text and ground, whichever
accent and level is chosen.

Weighed and not chosen:

- **Material's own surface roles** (`ColorScheme.fromSeed` with a neutral,
  tonal-spot or vibrant variant): less code, but it replaces nemo's tuned
  greys, so the default look would change for everyone, and the vibrant
  variant muddies the dark theme.
- **A hand-picked table**: nine accents (the style's own and eight
  slots), three levels, two brightnesses is 54 sets of colours to keep in
  step by hand.

## The tint

A pure function in `app/lib/core/theme/surface_tint.dart`, beside
`AppStyle`:

```dart
enum SurfaceTint { none, subtle, strong }

/// [color] with the hue of [accent], where there is one, and its
/// saturation scaled for [tint]; its lightness as it was.
Color tinted(Color color, SurfaceTint tint, {Color? accent});
```

- Saturation factor: `none` 0, `subtle` 1, `strong` 2.5, the result
  clamped to 1.
- Hue: the accent's HSL hue where `accent` is given, else `color`'s own.
- HSL lightness is not luminance, so saturation moves contrast a little.
  The contrast test below is the guard: if any accent fails at `strong`,
  the factor comes down until all pass, rather than special-casing hues.
- `subtle` with no accent returns `color` itself, untouched, so the
  default theme is today's to the bit rather than to within rounding.
- Pure white and pure black have no saturation to scale and stay as they
  are: the light theme's cards and sidebar stay white at every level;
  the tint shows in the window, containers, separators and input fill
  around them.

## Which colours

In `NemoTheme.light` and `NemoTheme.dark`, every colour that is a ground
or sits on one goes through `tinted`:

- the scaffold background (`F5F8F8` / `0E1616`);
- the scheme's `surface`, `onSurface`, `onSurfaceVariant`,
  `outlineVariant` and `surfaceContainerHighest`, as overridden today;
- the scheme's remaining surface roles from `ColorScheme.fromSeed`
  (`surfaceContainerLowest` … `surfaceContainerHigh`, `surfaceDim`,
  `surfaceBright`), which today stay teal whatever the accent;
- `NemoColors.sidebar` and `NemoColors.separator`.

Card, input, sheet and chip colours are already read from the scheme,
so they follow. Accent roles (`primary` and its container) and
`NemoColors.selection` keep coming from `accented` and `_withSelection`
as today. Priority, overdue and list palette colours are not touched.

## Wiring

- `SurfaceTint` lives in `surface_tint.dart`; `AppTheme.build` takes a
  `SurfaceTint tint = SurfaceTint.subtle` and passes it, with the chosen
  accent colour, to `NemoTheme.light/dark`. `MacosTheme` and
  `Material3Theme` do not take it.
- `KvKeys.surfaceTint = 'surface_tint'`, stored as the enum's name;
  anything else, or nothing, reads as `subtle`.
- `AppBootstrap.surfaceTint` (default `subtle`), loaded beside `accent`.
- `SurfaceTintController` in `settings_controller.dart`, shaped like
  `AccentController`.
- `app.dart` watches it and passes it to both `AppTheme.build` calls.

## Settings

Under `AccentPicker`, while the style is nemo, a `SegmentedButton<SurfaceTint>`
(key `surface-tint`) labelled "Background tint" with None, Subtle and
Strong, in the style of the theme-mode buttons above it. Hidden in the
macOS and Material styles; the stored value is kept, and applies again
when nemo is chosen again.

New strings in `app_en.arb`, `app_de.arb` and `app_it.arb`:
`settingsSurfaceTint`, `surfaceTintNone`, `surfaceTintSubtle`,
`surfaceTintStrong`.

## Testing

`test/core/theme/surface_tint_test.dart`:

- `none` gives saturation 0; lightness is unchanged at every level.
- `strong` is more saturated than `subtle`, and clamps at 1.
- `subtle` with no accent returns the colour unchanged.
- White and black are returned unchanged at every level.

`test/core/theme/app_theme_test.dart`:

- nemo, `subtle`, no accent: every tinted colour equals today's constant,
  light and dark.
- For every accent (none and the eight slots) × level × brightness,
  `onSurface` and `onSurfaceVariant` read at 4.5:1 or better on the
  scaffold, `surface`, `surfaceContainerHighest` and the sidebar.
- macOS and Material themes are the same whatever the tint.

`test/features/settings/settings_screen_test.dart`:

- The tint control shows in nemo and not in macOS or Material.
- Choosing Strong stores `strong` and the app's theme rebuilds with it.

## Out of scope

- Tint in the macOS and Material styles.
- Pure black (OLED) dark, contrast levels, background presets.
- Carrying the tint into the web splash or the Android home-screen widget.
