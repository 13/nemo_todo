# Maintenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the GitHub Actions, the Docker Dart image and `file_picker` to their current versions without changing app behaviour.

**Architecture:** Two local commits on `chore/maintenance` (Actions bumps, `file_picker` 13), merged into `main`; then, with the user's go-ahead, push, merge Dependabot PR #4 on GitHub and confirm PR #5 closes.

**Tech Stack:** GitHub Actions, Flutter 3.47.2 (via fvm), pub workspace.

Spec: `docs/superpowers/specs/2026-09-15-maintenance-design.md`

## Global Constraints

- `actions/checkout@v7`, `actions/setup-java@v6`, `actions/upload-artifact@v7`; `file_picker: ^13.0.0`.
- No app behaviour change; no other dependency changes beyond what `flutter pub get` resolves for `file_picker`.
- Flutter is not on PATH: `export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"`. Flutter commands from `app/`; `flutter pub get` and git from the repository root (pub workspace, single root `pubspec.lock`).
- Stage by path. Commit messages end with:
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse
- Never push, merge or close anything on GitHub without the user's explicit go-ahead (Task 3).

---

### Task 1: Bump the GitHub Actions

**Files:**
- Modify: `.github/workflows/ci.yml:23,116` (checkout), `:123` (setup-java), `:188` (upload-artifact)
- Modify: `.github/workflows/release.yml:28,184` (checkout), `:71` (setup-java)

**Interfaces:** none.

- [ ] **Step 1: Create the branch**

From the repository root, on a clean `main`: `git switch -c chore/maintenance`

- [ ] **Step 2: Edit the versions**

In both files replace every `uses: actions/checkout@v5` with `uses: actions/checkout@v7`, every `uses: actions/setup-java@v5` with `uses: actions/setup-java@v6`, and in `ci.yml` `uses: actions/upload-artifact@v5` with `uses: actions/upload-artifact@v7`. Leave every `with:` block unchanged.

- [ ] **Step 3: Verify**

```bash
grep -n "uses: actions/\(checkout\|setup-java\|upload-artifact\)@" .github/workflows/ci.yml .github/workflows/release.yml
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ('.github/workflows/ci.yml', '.github/workflows/release.yml')]; print('yaml ok')"
```

Expected: seven lines, all `@v7`/`@v6`/`@v7` as above, none `@v5`; `yaml ok`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/release.yml
git commit -m "build(deps): bump checkout to 7, setup-java to 6 and upload-artifact to 7

Applies what Dependabot proposed in #5 on top of this week's workflow
changes, instead of rebasing its pull request.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse"
```

---

### Task 2: Upgrade file_picker to 13

**Files:**
- Modify: `app/pubspec.yaml:19`
- Modify: `pubspec.lock` (repository root, regenerated)

**Interfaces:** none. `app/lib/features/settings/ui/data_tiles.dart` keeps compiling unchanged.

- [ ] **Step 1: Raise the constraint**

In `app/pubspec.yaml` replace `  file_picker: ^12.3.0` with `  file_picker: ^13.0.0`.

- [ ] **Step 2: Resolve**

Run from the repository root: `flutter pub get`
Expected: resolves `file_picker 13.0.0` and its `2.0.0`/`4.0.0` platform packages; `git diff --stat` shows only `app/pubspec.yaml` and `pubspec.lock`.

- [ ] **Step 3: Verify the app**

From `app/`:

```bash
flutter analyze
flutter test test/features/settings/data_tiles_test.dart test/features/settings/data_export_test.dart
flutter test --exclude-tags design
```

Expected: `No issues found!`; both files pass; full suite passes. If analyze reports a removed API in `data_tiles.dart`, stop and report it (the spec found none).

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml pubspec.lock
git commit -m "build(deps): upgrade file_picker to 13

Its breaking changes (removed deprecated parameters, a nullable
PlatformFile.length) do not reach the calls the app makes.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse"
```

---

### Task 3: Merge, and settle the Dependabot pull requests (controller, with the user's go-ahead)

**Files:** none.

- [ ] **Step 1: Merge locally**

```bash
git switch main && git merge --ff-only chore/maintenance && git branch -d chore/maintenance
(cd app && flutter test --exclude-tags design)
```

- [ ] **Step 2: Ask the user** before any of the following.

- [ ] **Step 3: Merge PR #4 on GitHub and bring it into main**

```bash
gh pr merge 4 --merge --delete-branch
git fetch origin && git merge --ff-only origin/main || git rebase origin/main
```

If `main` cannot fast-forward because PR #4's merge commit landed on `origin/main` after local commits, rebase the local commits onto `origin/main` (they touch different files) and rerun the suite.

- [ ] **Step 4: Push and watch CI**

```bash
git push origin main
gh run list --branch main --limit 1
```

Watch the run to success.

- [ ] **Step 5: Confirm PR #5 is closed**

`gh pr list` — PR #5 should be closed by Dependabot within a few minutes of the push. If it is still open after CI finishes, close it: `gh pr close 5 --comment "Applied on main in <sha of the Actions commit>."`
