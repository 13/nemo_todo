# Celebration Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the unlock banner up for screen-reader users, stop a sync-triggered backfill from swallowing a tap's unlock, and document that the chime may be silent in Safari.

**Architecture:** The overlay skips its hide timer under accessible navigation. The celebration controller runs completions and backfills one step at a time, with a tap's write inside its own step. The Safari limit is stated in README and the feature spec.

**Tech Stack:** Flutter 3.47.2 (via fvm), Riverpod 3, flutter_test.

Spec: `docs/superpowers/specs/2026-09-15-celebration-polish-design.md`

## Global Constraints

- Banner auto-hide stays exactly 4 s when accessible navigation is off.
- `onCompleted` and `backfill` never throw for celebration failures (unchanged); a failing `write` still throws to the caller.
- Unticking (`done: false`) never goes through the controller.
- Flutter is not on PATH: `export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"`. Flutter commands from `app/`; git from the repository root. Branch `chore/celebration-polish` from `main`.
- `dart format` changed files (CI checks formatting). Stage by path. Commit messages end with:
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse

---

### Task 1: The banner waits for screen-reader users

**Files:**
- Modify: `app/lib/features/celebrations/ui/celebration_overlay.dart` (`_show`, the `if (event is AchievementsUnlocked)` block)
- Test: `app/test/features/celebrations/celebration_overlay_test.dart`

**Interfaces:**
- Consumes: test helpers already in that file: `seedToday(List<String> titles, {Map<String, String> kv, bool done})`, `tickOff(WidgetTester, String title)`; `pumpApp(tester, celebrate:, seed:)`; `appTest`.

- [ ] **Step 1: Create the branch**

From the repository root on a clean `main`: `git switch -c chore/celebration-polish`

- [ ] **Step 2: Write the failing tests**

Append inside `main()` of `celebration_overlay_test.dart`:

```dart
  appTest('the banner hides itself after four seconds', (tester) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second']),
    );
    await tickOff(tester, 'First');
    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
  });

  appTest('with accessible navigation the banner waits to be closed', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second']),
    );
    await tickOff(tester, 'First');

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.byKey(const Key('achievement-banner')), findsNothing);
  });
```

- [ ] **Step 3: Run them**

Run: `flutter test test/features/celebrations/celebration_overlay_test.dart --plain-name "banner"`
Expected: "the banner hides itself after four seconds" PASSES (current behaviour, a guard); "with accessible navigation the banner waits to be closed" FAILS at the 6 s `findsOneWidget`.

- [ ] **Step 4: Implement**

In `_show`, replace

```dart
      _hideBanner?.cancel();
      _hideBanner = Timer(const Duration(seconds: 4), _closeBanner);
```

with

```dart
      _hideBanner?.cancel();
      // Reaching the banner with a screen reader or switch access takes
      // longer than a glance, so there it stays until it is closed.
      if (!MediaQuery.accessibleNavigationOf(context)) {
        _hideBanner = Timer(const Duration(seconds: 4), _closeBanner);
      }
```

- [ ] **Step 5: Run the overlay tests**

Run: `flutter test test/features/celebrations/celebration_overlay_test.dart`
Expected: all PASS, no pending-timer errors.

- [ ] **Step 6: Commit**

```bash
dart format app/lib/features/celebrations/ui/celebration_overlay.dart app/test/features/celebrations/celebration_overlay_test.dart
git add app/lib/features/celebrations/ui/celebration_overlay.dart app/test/features/celebrations/celebration_overlay_test.dart
git commit -m "fix(app): keep the unlock banner up for screen-reader users

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse"
```

---

### Task 2: A backfill cannot swallow a tap's unlock

**Files:**
- Modify: `app/lib/features/celebrations/ui/celebration_controller.dart`
- Modify: `app/lib/features/celebrations/ui/complete_task.dart`
- Test: `app/test/features/celebrations/celebration_controller_test.dart`

**Interfaces:**
- Produces: `Future<void> CelebrationController.onCompleted(Task task, {Future<void> Function()? write})` — existing callers without `write` keep working.
- Consumes (tests): helpers in `celebration_controller_test.dart`: `add(String title, {bool dueToday})`, `unlockedIds(CelebrationEvent)`, `events`, `controller`, `tasks`.

- [ ] **Step 1: Write the failing test**

Append inside `main()` of `celebration_controller_test.dart`:

```dart
  test('a backfill asked for during a tap does not swallow its unlock', () async {
    final a = await add('A');
    Future<void>? backfill;
    await controller.onCompleted(
      a,
      write: () async {
        await tasks.setDone(a.id, done: true);
        // A sync finishing right after the write asks for a backfill.
        backfill = controller.backfill();
      },
    );
    await backfill;
    await pumpEventQueue();

    expect(events, hasLength(1));
    expect(unlockedIds(events.single), ['first_done']);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/celebrations/celebration_controller_test.dart --plain-name "swallow"`
Expected: FAIL to compile (`No named parameter with the name 'write'`).

- [ ] **Step 3: Implement the turn-taking**

In `CelebrationController`, after the `_events` field, add:

```dart
  Future<void> _turn = Future<void>.value();

  /// Runs [step] after every step already asked for, so a completion and a
  /// backfill never interleave. The chain survives a step that throws; the
  /// caller of that step still sees the error.
  Future<void> _inTurn(Future<void> Function() step) {
    final next = _turn.then((_) => step());
    _turn = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
```

Replace the `onCompleted` declaration line and its opening so the existing body becomes a private method:

```dart
  /// After [task] was ticked off by a tap. [write] -- the tap's own write --
  /// runs in the same turn as the check, so a backfill asked for while it
  /// runs (a sync finishing) cannot record this tap's unlock first and
  /// swallow its banner. A failing [write] throws to the caller; a
  /// celebration going wrong never does.
  Future<void> onCompleted(Task task, {Future<void> Function()? write}) =>
      _inTurn(() async {
        if (write != null) await write();
        await _celebrate(task);
      });

  Future<void> _celebrate(Task task) async {
    try {
      // ... the existing body of onCompleted, unchanged ...
    } on Object catch (error, stack) {
      debugPrint('Celebration failed: $error\n$stack');
    }
  }
```

(Move the existing `try { ... } on Object catch ...` body verbatim into `_celebrate`; do not change its logic.)

Replace `backfill` with:

```dart
  /// Records everything already reached as celebrated, without a sound.
  ///
  /// Run at start and after every sync: nothing reached by then was a tap
  /// on this device, because a tap is celebrated in the turn it happens.
  Future<void> backfill() => _inTurn(() async {
    try {
      await _repo.markSeen((await _reached()).map((a) => a.id));
    } on Object catch (error, stack) {
      debugPrint('Achievement backfill failed: $error\n$stack');
    }
  });
```

- [ ] **Step 4: Route taps through the turn**

In `app/lib/features/celebrations/ui/complete_task.dart`, replace

```dart
  await tasks.setDone(task.id, done: done);
  if (done) await celebrations.onCompleted(task);
```

with

```dart
  if (!done) {
    await tasks.setDone(task.id, done: false);
    return;
  }
  await celebrations.onCompleted(
    task,
    write: () => tasks.setDone(task.id, done: true),
  );
```

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/celebrations/ test/features/tasks/task_swipe_test.dart
flutter test --exclude-tags design
flutter analyze
```

Expected: all PASS (including the new test and every existing controller, overlay and swipe test); `No issues found!`.

- [ ] **Step 6: Commit**

```bash
dart format app/lib/features/celebrations/ui/celebration_controller.dart app/lib/features/celebrations/ui/complete_task.dart app/test/features/celebrations/celebration_controller_test.dart
git add app/lib/features/celebrations/ui/celebration_controller.dart app/lib/features/celebrations/ui/complete_task.dart app/test/features/celebrations/celebration_controller_test.dart
git commit -m "fix(app): celebrate a tap before a sync's backfill records it

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse"
```

---

### Task 3: Say that Safari may keep the chime silent

**Files:**
- Modify: `README.md:21-24`
- Modify: `docs/superpowers/specs/2026-09-14-achievements-celebrations-design.md` (Sound section)

- [ ] **Step 1: README**

Replace

```markdown
- Ticking a task off feels like it: a small bounce on every tick, confetti
  when Today is cleared, and ten achievements to unlock, from the first
  task done to a 30-day streak. Settings turns celebrations, their sound
  and achievements off one by one, for a quieter, more professional app.
```

with

```markdown
- Ticking a task off feels like it: a small bounce on every tick, confetti
  when Today is cleared, and ten achievements to unlock, from the first
  task done to a 30-day streak. Settings turns celebrations, their sound
  and achievements off one by one, for a quieter, more professional app.
  In Safari the sound may stay silent: Safari plays sound only right after
  a tap, and the chime comes a moment later.
```

- [ ] **Step 2: Spec**

In the Sound section of `docs/superpowers/specs/2026-09-14-achievements-celebrations-design.md`, after the sentence ending `a missing codec never breaks ticking a task. Tests use a fake.`, add on the next line of the same paragraph:

```markdown
Safari plays sound only in direct response to a tap; the chime starts after
the controller's queries, so Safari may refuse it and it stays silent there.
```

- [ ] **Step 3: CHANGELOG**

In `CHANGELOG.md`, if there is no `## Unreleased` heading above the newest version heading, add one directly above it (with a blank line after). Under it, add a `### Fixed` section (or append to it if present):

```markdown
### Fixed

- The achievement banner no longer hides after four seconds for people
  moving through the app with a screen reader or switch access; it waits
  until it is closed.
- An achievement unlocked by a tap can no longer go uncelebrated because a
  sync finished at the same moment.
```

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-09-14-achievements-celebrations-design.md CHANGELOG.md
git commit -m "docs: note that Safari may keep the chime silent

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse"
```
