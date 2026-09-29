# Background Tint for the nemo Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the nemo style, let the window, surfaces and sidebar take their tint from the chosen accent, at None, Subtle or Strong, chosen in Settings.

**Architecture:** A pure `tinted(color, tint, accent:)` function keeps a colour's HSL lightness, swaps in the accent's hue and scales saturation by the level. `NemoTheme` runs every ground colour through it; `AppTheme.build` gains a `tint` argument that only the nemo style reads. The level is a device-local key-value setting with a Riverpod controller, a bootstrap field and a segmented button under the accent picker.

**Tech Stack:** Flutter (Material 3, `ThemeExtension`), Riverpod with `riverpod_annotation` codegen, drift key-value store, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-09-29-nemo-surface-tint-design.md`

## Global Constraints

- Levels are exactly `SurfaceTint { none, subtle, strong }`; saturation factor none 0, subtle 1, strong 2.5, clamped to 1.
- Default `subtle`; nemo with `subtle` and no accent must equal today's colours to the bit.
- nemo style only: `MacosTheme` and `Material3Theme` are not changed and do not take a tint.
- Stored under `KvKeys.surfaceTint = 'surface_tint'` as the enum's name; anything else, or nothing, reads as `subtle`. Device-local, not synced.
- `onSurface` and `onSurfaceVariant` stay at 4.5:1 or better on scaffold, `surface`, `surfaceContainerHighest` and sidebar for every accent × level × brightness. If `strong` fails, lower its factor (e.g. 2.0, then 1.75) for all hues; do not special-case hues.
- Accent roles, `NemoColors.selection`, priority, overdue and list palette colours are not tinted.
- Web splash and Android widget are not changed.
- Flutter is at `~/flutter/bin/flutter` (not on PATH). Run `tool/check.sh` before the final commit; plain `flutter analyze` misses the riverpod_lint plugin CI enforces.
- Comment style in this repo: short doc comments in plain prose, no "Returns …" boilerplate. Match it.

## Review Focus

1. A stored value that is not a level name (older build, typo, empty) — app starts in `subtle`, no crash. Test in Task 3.
2. Switching to macOS and back to nemo — the chosen level is kept and applied again. Test in Task 3.
3. Changing the accent while on `strong` — the backgrounds follow the new accent's hue. Test in Task 2.
4. The grey accent (slot 7) and the teal accent (slot 0) at `strong` in dark — text still reads. Covered by the all-accents contrast loop in Task 2.
5. A tint picked in the nemo style has no effect on macOS/Material themes. Test in Task 2.

---

## File Structure

- Create `app/lib/core/theme/surface_tint.dart` — `SurfaceTint` enum and `tinted()`; nothing else.
- Modify `app/lib/core/theme/nemo_theme.dart` — take `tint`, run ground colours through `tinted`.
- Modify `app/lib/core/theme/app_theme.dart` — `build(..., tint:)` passes it to nemo.
- Modify `app/lib/core/db/kv_store.dart`, `app/lib/core/providers.dart` — key and bootstrap field.
- Modify `app/lib/features/settings/ui/settings_controller.dart` (+ regenerated `.g.dart`) — `SurfaceTintController`.
- Create `app/lib/features/settings/ui/surface_tint_picker.dart` — the segmented button.
- Modify `app/lib/features/settings/ui/settings_screen.dart`, `app/lib/app.dart`, `app/test/support/pump_app.dart` — wiring.
- Modify `app/lib/l10n/app_{en,de,it}.arb` (+ regenerated `app_localizations*.dart`).
- Tests: `app/test/core/theme/surface_tint_test.dart` (new), `app/test/core/theme/app_theme_test.dart`, `app/test/features/settings/settings_screen_test.dart`.

---

### Task 1: The tint function

**Files:**
- Create: `app/lib/core/theme/surface_tint.dart`
- Test: `app/test/core/theme/surface_tint_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum SurfaceTint { none, subtle, strong }`; `Color tinted(Color color, SurfaceTint tint, {Color? accent})`.

- [ ] **Step 1: Write the failing tests**

`app/test/core/theme/surface_tint_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/surface_tint.dart';

void main() {
  const window = Color(0xFFF5F8F8);
  const container = Color(0xFFECF3F2);
  const darkWindow = Color(0xFF0E1616);
  const pink = Color(0xFFD64577);

  HSLColor hsl(Color c) => HSLColor.fromColor(c);

  test('subtle with no accent is the colour itself', () {
    for (final c in [window, container, darkWindow]) {
      expect(tinted(c, SurfaceTint.subtle), c);
    }
  });

  test('none is grey', () {
    for (final c in [window, container, darkWindow]) {
      expect(hsl(tinted(c, SurfaceTint.none)).saturation, 0);
      expect(hsl(tinted(c, SurfaceTint.none, accent: pink)).saturation, 0);
    }
  });

  test('lightness is kept at every level and accent', () {
    for (final c in [window, container, darkWindow]) {
      for (final t in SurfaceTint.values) {
        for (final a in [null, pink]) {
          expect(
            hsl(tinted(c, t, accent: a)).lightness,
            closeTo(hsl(c).lightness, 0.01),
            reason: '$c $t $a',
          );
        }
      }
    }
  });

  test('strong is more saturated than subtle, and no more than full', () {
    for (final c in [window, container, darkWindow]) {
      final subtle = hsl(tinted(c, SurfaceTint.subtle, accent: pink));
      final strong = hsl(tinted(c, SurfaceTint.strong, accent: pink));
      expect(strong.saturation, greaterThan(subtle.saturation));
      expect(strong.saturation, lessThanOrEqualTo(1));
    }
    // Saturation ~0.43: x2.5 passes 1 and must clamp.
    const vivid = Color(0xFF3FA0A0);
    expect(hsl(tinted(vivid, SurfaceTint.strong)).saturation, closeTo(1, 0.01));
  });

  test('an accent gives its hue', () {
    final t = tinted(container, SurfaceTint.subtle, accent: pink);
    // A faint colour's hue is coarse in 8-bit channels.
    expect(hsl(t).hue, closeTo(hsl(pink).hue, 10));
  });

  test('white and black stay as they are', () {
    for (final c in [Colors.white, Colors.black]) {
      for (final t in SurfaceTint.values) {
        expect(tinted(c, t, accent: pink), c, reason: '$c $t');
      }
    }
  });
}
```

- [ ] **Step 2: Run to see it fail**

Run: `cd app && ~/flutter/bin/flutter test test/core/theme/surface_tint_test.dart`
Expected: FAIL — `surface_tint.dart` does not exist.

- [ ] **Step 3: Implement**

`app/lib/core/theme/surface_tint.dart`:

```dart
import 'package:flutter/material.dart';

/// How much of the accent the nemo style's window and surfaces take on,
/// chosen in Settings beside the accent.
enum SurfaceTint {
  /// Plain greys.
  none,

  /// As nemo has always been: a faint cast; the default.
  subtle,

  /// A cast you notice.
  strong,
}

/// [color] with the hue of [accent], where there is one, and its
/// saturation scaled for [tint]; its lightness as it was.
///
/// Lightness is what nemo's hand-tuned greys differ in, and what keeps
/// text readable on them, so only the cast changes. White and black have
/// no cast to change and come back as they went in.
Color tinted(Color color, SurfaceTint tint, {Color? accent}) {
  // The default theme is today's to the bit, not to within rounding.
  if (tint == SurfaceTint.subtle && accent == null) return color;
  final hsl = HSLColor.fromColor(color);
  final factor = switch (tint) {
    SurfaceTint.none => 0.0,
    SurfaceTint.subtle => 1.0,
    SurfaceTint.strong => 2.5,
  };
  return hsl
      .withHue(accent == null ? hsl.hue : HSLColor.fromColor(accent).hue)
      .withSaturation((hsl.saturation * factor).clamp(0.0, 1.0))
      .toColor();
}
```

- [ ] **Step 4: Run to see it pass**

Run: `cd app && ~/flutter/bin/flutter test test/core/theme/surface_tint_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/theme/surface_tint.dart app/test/core/theme/surface_tint_test.dart
git commit -m "feat(theme): a surface tint that keeps a colour's lightness"
```

---

### Task 2: nemo's theme takes the tint

**Files:**
- Modify: `app/lib/core/theme/nemo_theme.dart` (`light`, `dark`, `_withSelection` callers)
- Modify: `app/lib/core/theme/app_theme.dart` (`build`)
- Test: `app/test/core/theme/app_theme_test.dart` (append a `group`)

**Interfaces:**
- Consumes: `SurfaceTint`, `tinted` from Task 1.
- Produces: `AppTheme.build(AppStyle style, Brightness brightness, {WallpaperSchemes? wallpaper, int? accent, SurfaceTint tint = SurfaceTint.subtle})`; `NemoTheme.light({Color? accent, SurfaceTint tint = SurfaceTint.subtle})`, same for `dark`.

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `app/test/core/theme/app_theme_test.dart` (add `import 'package:nemo/core/theme/surface_tint.dart';`; the file's own `contrast` helper is in scope):

```dart
  group('surface tint', () {
    test('nemo subtle with no accent is nemo as it was', () {
      final light = AppTheme.build(AppStyle.nemo, Brightness.light);
      expect(light.scaffoldBackgroundColor, const Color(0xFFF5F8F8));
      expect(light.colorScheme.surface, Colors.white);
      expect(light.colorScheme.onSurface, const Color(0xFF16211F));
      expect(light.colorScheme.onSurfaceVariant, const Color(0xFF45524F));
      expect(light.colorScheme.outlineVariant, const Color(0xFFD9E3E1));
      expect(
        light.colorScheme.surfaceContainerHighest,
        const Color(0xFFECF3F2),
      );
      expect(light.extension<NemoColors>(), NemoColors.light);

      final dark = AppTheme.build(AppStyle.nemo, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0E1616));
      expect(dark.colorScheme.surface, const Color(0xFF151F1F));
      expect(dark.colorScheme.onSurface, const Color(0xFFE3ECEB));
      expect(dark.colorScheme.onSurfaceVariant, const Color(0xFFA7B8B6));
      expect(dark.colorScheme.outlineVariant, const Color(0xFF2A3837));
      expect(
        dark.colorScheme.surfaceContainerHighest,
        const Color(0xFF1D2A29),
      );
      expect(dark.extension<NemoColors>(), NemoColors.dark);
    });

    for (final brightness in Brightness.values) {
      for (final tint in SurfaceTint.values) {
        for (final accent in [null, 0, 1, 2, 3, 4, 5, 6, 7]) {
          test('nemo ${brightness.name} $tint accent $accent: text reads', () {
            final theme = AppTheme.build(
              AppStyle.nemo,
              brightness,
              accent: accent,
              tint: tint,
            );
            final s = theme.colorScheme;
            final grounds = [
              theme.scaffoldBackgroundColor,
              s.surface,
              s.surfaceContainerHighest,
              theme.extension<NemoColors>()!.sidebar,
            ];
            for (final bg in grounds) {
              expect(contrast(s.onSurface, bg), greaterThanOrEqualTo(4.5));
              expect(
                contrast(s.onSurfaceVariant, bg),
                greaterThanOrEqualTo(4.5),
                reason: 'onSurfaceVariant on $bg',
              );
            }
          });
        }
      }
    }

    test('none is grey, strong more coloured than subtle', () {
      double sat(SurfaceTint t) => HSLColor.fromColor(
        AppTheme.build(
          AppStyle.nemo,
          Brightness.light,
          accent: 3,
          tint: t,
        ).scaffoldBackgroundColor,
      ).saturation;
      expect(sat(SurfaceTint.none), 0);
      expect(sat(SurfaceTint.strong), greaterThan(sat(SurfaceTint.subtle)));
    });

    test('the backgrounds follow a changed accent', () {
      Color window(int accent) => AppTheme.build(
        AppStyle.nemo,
        Brightness.dark,
        accent: accent,
        tint: SurfaceTint.strong,
      ).scaffoldBackgroundColor;
      final pink = HSLColor.fromColor(window(3)).hue;
      final green = HSLColor.fromColor(window(6)).hue;
      expect((pink - green).abs(), greaterThan(60));
    });

    for (final style in [AppStyle.macos, AppStyle.material]) {
      for (final brightness in Brightness.values) {
        test('${style.name} ${brightness.name} ignores the tint', () {
          ThemeData at(SurfaceTint t) =>
              AppTheme.build(style, brightness, accent: 2, tint: t);
          expect(at(SurfaceTint.none).colorScheme, at(SurfaceTint.strong).colorScheme);
          expect(
            at(SurfaceTint.none).scaffoldBackgroundColor,
            at(SurfaceTint.strong).scaffoldBackgroundColor,
          );
        });
      }
    }
  });
```

- [ ] **Step 2: Run to see it fail**

Run: `cd app && ~/flutter/bin/flutter test test/core/theme/app_theme_test.dart`
Expected: compile FAIL — `No named parameter with the name 'tint'`.

- [ ] **Step 3: Implement in `nemo_theme.dart`**

Add `import 'package:nemo/core/theme/surface_tint.dart';`. Replace `light` and `dark` with:

```dart
  static ThemeData light({
    Color? accent,
    SurfaceTint tint = SurfaceTint.subtle,
  }) {
    Color t(Color c) => tinted(c, tint, accent: accent);
    final base = _tintedScheme(
      ColorScheme.fromSeed(seedColor: seed).copyWith(
        primary: seed,
        surface: Colors.white,
        onSurface: const Color(0xFF16211F),
        onSurfaceVariant: const Color(0xFF45524F),
        outlineVariant: const Color(0xFFD9E3E1),
        surfaceContainerHighest: const Color(0xFFECF3F2),
      ),
      t,
    );
    final scheme = accented(base, accent);
    return _base(
      scheme,
      _withSelection(_tintedColors(NemoColors.light, t), scheme, accent),
    ).copyWith(scaffoldBackgroundColor: t(const Color(0xFFF5F8F8)));
  }

  static ThemeData dark({
    Color? accent,
    SurfaceTint tint = SurfaceTint.subtle,
  }) {
    Color t(Color c) => tinted(c, tint, accent: accent);
    final base = _tintedScheme(
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF5BC0C9),
        onPrimary: const Color(0xFF00363B),
        surface: const Color(0xFF151F1F),
        onSurface: const Color(0xFFE3ECEB),
        onSurfaceVariant: const Color(0xFFA7B8B6),
        outlineVariant: const Color(0xFF2A3837),
        surfaceContainerHighest: const Color(0xFF1D2A29),
      ),
      t,
    );
    final scheme = accented(base, accent);
    return _base(
      scheme,
      _withSelection(_tintedColors(NemoColors.dark, t), scheme, accent),
    ).copyWith(scaffoldBackgroundColor: t(const Color(0xFF0E1616)));
  }

  /// [scheme]'s grounds, and the text and hairlines on them, through [t];
  /// its accent roles as they were.
  static ColorScheme _tintedScheme(
    ColorScheme scheme,
    Color Function(Color) t,
  ) => scheme.copyWith(
    surface: t(scheme.surface),
    onSurface: t(scheme.onSurface),
    onSurfaceVariant: t(scheme.onSurfaceVariant),
    outlineVariant: t(scheme.outlineVariant),
    surfaceDim: t(scheme.surfaceDim),
    surfaceBright: t(scheme.surfaceBright),
    surfaceContainerLowest: t(scheme.surfaceContainerLowest),
    surfaceContainerLow: t(scheme.surfaceContainerLow),
    surfaceContainer: t(scheme.surfaceContainer),
    surfaceContainerHigh: t(scheme.surfaceContainerHigh),
    surfaceContainerHighest: t(scheme.surfaceContainerHighest),
  );

```

And the sidebar and hairlines. `NemoColors` has no `==`, so return `nemo` itself when nothing changed (subtle, no accent), or the Step 1 test comparing against `NemoColors.light` fails:

```dart
  /// [nemo]'s sidebar and hairlines through [t].
  static NemoColors _tintedColors(NemoColors nemo, Color Function(Color) t) {
    final sidebar = t(nemo.sidebar);
    final separator = t(nemo.separator);
    return sidebar == nemo.sidebar && separator == nemo.separator
        ? nemo
        : nemo.copyWith(sidebar: sidebar, separator: separator);
  }
```

- [ ] **Step 4: Implement in `app_theme.dart`**

Add `import 'package:nemo/core/theme/surface_tint.dart';`. Change `build`:

```dart
  /// [style] in [brightness]. [wallpaper] colours the Material style where
  /// the device has offered its own; [accent], a slot of [accents], replaces
  /// the style's own accent in any style; [tint] is how much of it the nemo
  /// style's backgrounds take on, and the other styles ignore it.
  static ThemeData build(
    AppStyle style,
    Brightness brightness, {
    WallpaperSchemes? wallpaper,
    int? accent,
    SurfaceTint tint = SurfaceTint.subtle,
  }) {
    final chosen = accent == null
        ? null
        : accents(style)[accent % accents(style).length];
    return switch ((style, brightness)) {
      (AppStyle.nemo, Brightness.light) =>
        NemoTheme.light(accent: chosen, tint: tint),
      (AppStyle.nemo, Brightness.dark) =>
        NemoTheme.dark(accent: chosen, tint: tint),
      (AppStyle.macos, Brightness.light) => MacosTheme.light(accent: chosen),
      (AppStyle.macos, Brightness.dark) => MacosTheme.dark(accent: chosen),
      (AppStyle.material, _) => Material3Theme.build(
        brightness,
        wallpaper: brightness == Brightness.light
            ? wallpaper?.light
            : wallpaper?.dark,
        accent: chosen,
      ),
    };
  }
```

- [ ] **Step 5: Run to see it pass**

Run: `cd app && ~/flutter/bin/flutter test test/core/theme/`
Expected: all PASS. If a `strong` contrast case fails, lower `SurfaceTint.strong`'s factor in `surface_tint.dart` (2.0, then 1.75) until every case passes. Do not add per-hue exceptions. Then re-run Task 1's tests (they only assert strong > subtle).

- [ ] **Step 6: Run the whole app suite for regressions**

Run: `cd app && ~/flutter/bin/flutter test`
Expected: all PASS (default `subtle` keeps every existing golden/a11y test's colours).

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/theme/nemo_theme.dart app/lib/core/theme/app_theme.dart app/test/core/theme/app_theme_test.dart
git commit -m "feat(theme): nemo's backgrounds take the accent's tint"
```

---

### Task 3: Choose the tint in Settings

**Files:**
- Modify: `app/lib/core/db/kv_store.dart` (after `accent`)
- Modify: `app/lib/core/providers.dart` (`AppBootstrap` field, constructor, `load`)
- Modify: `app/lib/features/settings/ui/settings_controller.dart` (+ regenerated `settings_controller.g.dart`)
- Create: `app/lib/features/settings/ui/surface_tint_picker.dart`
- Modify: `app/lib/features/settings/ui/settings_screen.dart` (after `const AccentPicker(),`)
- Modify: `app/lib/app.dart:120-136`, `app/test/support/pump_app.dart:239-249`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb` (+ regenerated `app_localizations*.dart`)
- Test: `app/test/features/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `SurfaceTint` (Task 1), `AppTheme.build(..., tint:)` (Task 2).
- Produces: `KvKeys.surfaceTint`; `AppBootstrap.surfaceTint`; `surfaceTintControllerProvider` (state `SurfaceTint`, `Future<void> set(SurfaceTint)`); widget `SurfaceTintPicker` with `Key('surface-tint')`; l10n getters `settingsSurfaceTint`, `surfaceTintNone`, `surfaceTintSubtle`, `surfaceTintStrong`.

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `app/test/features/settings/settings_screen_test.dart` (add `import 'package:nemo/core/theme/surface_tint.dart';`):

```dart
  appTest('a tint choice is applied and persisted', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.settings);
    Color window() => tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .scaffoldBackgroundColor;
    final subtle = window();
    expect(find.byKey(const Key('surface-tint')), findsOneWidget);
    await tester.ensureVisible(find.text('Strong'));
    await tester.tap(find.text('Strong'));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.surfaceTint), 'strong');
    expect(window(), isNot(subtle));
  });

  appTest('the tint shows only in the nemo style, and is kept', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      seed: (db, _) => KvStore(db).set(KvKeys.surfaceTint, 'none'),
    );
    Color window() => tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .scaffoldBackgroundColor;
    final none = window();
    await tester.tap(find.text('macOS'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('surface-tint')), findsNothing);
    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('surface-tint')), findsNothing);
    await tester.tap(find.text('nemo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('surface-tint')), findsOneWidget);
    expect(await KvStore(app.db).get(KvKeys.surfaceTint), 'none');
    expect(window(), none);
  });

  appTest('a stored tint that is not a level starts as subtle', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      seed: (db, _) => KvStore(db).set(KvKeys.surfaceTint, 'loud'),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFFF5F8F8));
    final picker = tester.widget<SegmentedButton<SurfaceTint>>(
      find.byKey(const Key('surface-tint')),
    );
    expect(picker.selected, {SurfaceTint.subtle});
  });
```

If `find.text('nemo')` matches more than one widget on the settings screen, use `find.descendant(of: find.byKey(const Key('app-style')), matching: find.text('nemo'))` instead, and likewise for 'macOS'/'Material'.

- [ ] **Step 2: Run to see it fail**

Run: `cd app && ~/flutter/bin/flutter test test/features/settings/settings_screen_test.dart`
Expected: compile FAIL — `KvKeys.surfaceTint` is not defined.

- [ ] **Step 3: Key and bootstrap**

In `app/lib/core/db/kv_store.dart`, after `accent`:

```dart
  /// How much of the accent the nemo style's backgrounds take on: a
  /// `SurfaceTint` name; unset for subtle.
  static const surfaceTint = 'surface_tint';
```

In `app/lib/core/providers.dart`: add `import 'package:nemo/core/theme/surface_tint.dart';`; constructor param `this.surfaceTint = SurfaceTint.subtle,` after `this.accent,`; field after `accent`:

```dart
  /// How much of the accent the nemo style's backgrounds take on.
  final SurfaceTint surfaceTint;
```

and in `load`, after the `accent:` line:

```dart
      surfaceTint:
          SurfaceTint.values.asNameMap()[await kv.get(KvKeys.surfaceTint)] ??
          SurfaceTint.subtle,
```

- [ ] **Step 4: Controller**

In `settings_controller.dart` add `import 'package:nemo/core/theme/surface_tint.dart';` and after `AccentController`:

```dart
/// How much of the accent the nemo style's backgrounds take on.
@Riverpod(keepAlive: true)
class SurfaceTintController extends _$SurfaceTintController {
  @override
  SurfaceTint build() => ref.watch(bootstrapProvider).surfaceTint;

  Future<void> set(SurfaceTint tint) async {
    state = tint;
    await ref.read(kvStoreProvider).set(KvKeys.surfaceTint, tint.name);
  }
}
```

Regenerate: `cd app && dart run build_runner build` (with `~/flutter/bin` on PATH: `PATH=~/flutter/bin:$PATH dart run build_runner build`).

- [ ] **Step 5: Wire the theme**

In `app/lib/app.dart` after `final accent = ...`: `final tint = ref.watch(surfaceTintControllerProvider);` and add `tint: tint,` to both `AppTheme.build` calls.

In `app/test/support/pump_app.dart`, add to both `AppTheme.build` calls: `tint: ref.watch(surfaceTintControllerProvider),`.

- [ ] **Step 6: Strings**

`app_en.arb`, after `"accentDefault"`:

```json
  "settingsSurfaceTint": "Background tint",
  "surfaceTintNone": "None",
  "surfaceTintSubtle": "Subtle",
  "surfaceTintStrong": "Strong",
```

`app_de.arb`, after `"accentDefault"`:

```json
  "settingsSurfaceTint": "Hintergrundtönung",
  "surfaceTintNone": "Keine",
  "surfaceTintSubtle": "Dezent",
  "surfaceTintStrong": "Kräftig",
```

`app_it.arb`, after `"accentDefault"`:

```json
  "settingsSurfaceTint": "Tinta dello sfondo",
  "surfaceTintNone": "Nessuna",
  "surfaceTintSubtle": "Leggera",
  "surfaceTintStrong": "Intensa",
```

If `app_en.arb` carries `@key` description entries for neighbouring keys, add one for each new key in the same form. Regenerate: `cd app && ~/flutter/bin/flutter gen-l10n`.

- [ ] **Step 7: The picker**

`app/lib/features/settings/ui/surface_tint_picker.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/surface_tint.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// How much of the accent nemo's backgrounds take on; only the nemo style
/// has it, so elsewhere this is nothing.
class SurfaceTintPicker extends ConsumerWidget {
  const SurfaceTintPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appStyleControllerProvider) != AppStyle.nemo) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.settingsSurfaceTint,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<SurfaceTint>(
            key: const Key('surface-tint'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: SurfaceTint.none,
                label: Text(l.surfaceTintNone),
              ),
              ButtonSegment(
                value: SurfaceTint.subtle,
                label: Text(l.surfaceTintSubtle),
              ),
              ButtonSegment(
                value: SurfaceTint.strong,
                label: Text(l.surfaceTintStrong),
              ),
            ],
            selected: {ref.watch(surfaceTintControllerProvider)},
            onSelectionChanged: (s) =>
                ref.read(surfaceTintControllerProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}
```

In `settings_screen.dart`, import it and add `const SurfaceTintPicker(),` directly after `const AccentPicker(),`.

- [ ] **Step 8: Run to see it pass**

Run: `cd app && ~/flutter/bin/flutter test test/features/settings/ test/a11y/`
Expected: all PASS (a11y guidelines check the new control's tap size and labels).

- [ ] **Step 9: Full check**

Run: `tool/check.sh` from the repo root.
Expected: every step passes, generated code current.

- [ ] **Step 10: Commit**

```bash
git add app/lib app/test
git commit -m "feat(settings): choose how much of the accent nemo's backgrounds take"
```
