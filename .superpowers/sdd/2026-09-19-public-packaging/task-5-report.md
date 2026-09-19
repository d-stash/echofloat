# Task 5 Report — Continuous Integration and End-to-End Validation

## Status
Completed with one explicit manual follow-up still required for System Settings UI verification of Launch at Login.

## Files changed
Committed:
- `.github/workflows/ci.yml`
- `Tests/PackagingChecks.sh`
- `Tests/InstallerChecks.sh`
- `setup.sh`

Report artifact (not committed):
- `.superpowers/sdd/2026-09-19-public-packaging/task-5-report.md`

## CI design
Added a single read-only `CI` workflow for `push` to `main` and all `pull_request`s.

Job shape:
- `macos-15`
- `permissions: contents: read`
- workflow/ref concurrency cancellation
- sequential steps for:
  1. shell syntax validation
  2. serialized Swift test suite with command-scoped `safe.bareRepository=all`
  3. standalone animation checks
  4. standalone playback timing checks
  5. packaging checks
  6. installer lifecycle checks

Notes:
- SwiftPM invocations use command-scoped `safe.bareRepository` override.
- Full-suite `swift test` is serialized with `--no-parallel` because two `PlayerViewModel` tests are timing-sensitive under concurrent execution but pass reliably when the suite runs serially.
- Packaging and installer steps remain separate and sequential, which also avoids local contention on `.build/iconset` during icon generation.

## Validation commands and exact outcomes
All final validation commands were run from:
`/Users/dpandey/Library/CloudStorage/OneDrive-Varonis/Desktop/personal-dev/echofloat/.worktrees/echofloat-mvp`

### 1) Shell syntax
Command:
```bash
rtk bash -n setup.sh scripts/*.sh Tests/*.sh
```
Outcome:
- Exit `0`
- No output

### 2) Swift tests
Command:
```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all rtk swift test --no-parallel
```
Outcome:
- Exit `0`
- `35` tests passed
- Notable launch-at-login related passing tests included:
  - `reflectsServiceStatus()`
  - `enablingRegistersMainApp()`
  - `disablingUnregistersMainApp()`
  - `registrationErrorsPropagate()`
  - `menuNeedsUpdateRefreshesAutostartStatusBeforeOpen()`

### 3) Standalone animation checks
Command:
```bash
rtk mkdir -p .build/ci-local-checks && \
rtk swiftc Sources/echofloat/Theming/Theme.swift \
  Sources/echofloat/Theming/ThemeAnimation.swift \
  Tests/ThemeAnimationChecks.swift \
  -o .build/ci-local-checks/theme-checks && \
rtk .build/ci-local-checks/theme-checks
```
Outcome:
- Exit `0`
- No output

### 4) Standalone playback timing checks
Command:
```bash
rtk mkdir -p .build/ci-local-checks && \
rtk swiftc Sources/echofloat/Models/TrackSignature.swift \
  Sources/echofloat/Models/NowPlayingState.swift \
  Sources/echofloat/Playback/PlaybackClock.swift \
  Tests/PlaybackTimingChecks.swift \
  -o .build/ci-local-checks/playback-checks && \
rtk .build/ci-local-checks/playback-checks
```
Outcome:
- Exit `0`
- No output

### 5) Packaging checks
Command:
```bash
rtk bash Tests/PackagingChecks.sh
```
Outcome:
- Exit `0`
- Generated fresh icon files
- Built production app
- `plutil` verification reported `Info.plist: OK`
- `codesign --verify --deep --strict` passed
- Final line: `Packaging checks passed`

### 6) Installer lifecycle checks
Command:
```bash
rtk bash Tests/InstallerChecks.sh
```
Outcome:
- Exit `0`
- Built and installed into isolated test home/install roots
- Reinstall path replaced prior app contents as expected
- Non-purge uninstall preserved support data/defaults
- Purge uninstall removed support data/defaults
- Guardrail failures for unsafe install paths still triggered as expected
- Final line: `Installer checks passed`

## Installed app validation
Preflight process check:
```bash
rtk proxy ps aux | grep echofloat | grep -v grep
```
Outcome:
- Exit `1`
- No pre-existing Echofloat process found

Install + validate command:
```bash
rtk ./setup.sh --no-launch && \
rtk /usr/bin/plutil -lint "$HOME/Applications/Echofloat.app/Contents/Info.plist" && \
rtk /usr/bin/codesign --verify --deep --strict "$HOME/Applications/Echofloat.app" && \
rtk /usr/bin/open "$HOME/Applications/Echofloat.app" && \
rtk /bin/sleep 2 && \
rtk pgrep -f "$HOME/Applications/Echofloat.app/Contents/MacOS/echofloat"
```
Outcome:
- Exit `0`
- `setup.sh --no-launch` ran serialized tests, packaged app, and installed to approved default path:
  - `/Users/dpandey/Applications/Echofloat.app`
- `plutil` reported `Info.plist: OK`
- `codesign --verify --deep --strict` passed
- `pgrep` returned installed-app PID: `47387`

Post-check cleanup:
```bash
rtk kill 47387
rtk pgrep -f "/Users/dpandey/Applications/Echofloat.app/Contents/MacOS/echofloat"
```
Outcome:
- `kill 47387` exit `0`
- follow-up `pgrep` exit `1`, confirming the validated installed instance was stopped

## Launch at Login evidence and manual gap
Non-destructive programmatic evidence gathered:
- Launch-at-login unit coverage passed in the serialized Swift suite:
  - register path
  - unregister path
  - error propagation path
  - menu-title/status refresh path
- Installer lifecycle checks also verified legacy launch-agent cleanup and uninstall behavior in isolated homes.

What was **not** claimed:
- I did **not** claim System Settings visibility/approval was verified.
- I did **not** enable a persistent login item in the live user environment.

Remaining manual action:
1. Launch installed Echofloat from `~/Applications/Echofloat.app`.
2. Toggle **Launch at Login** from the menu.
3. Open **System Settings > General > Login Items**.
4. Confirm Echofloat appears/enables correctly.
5. Disable it again unless it was already enabled beforehand.
6. If macOS shows approval-required state, approve it there and repeat the check.

## Git artifact checks
Commands:
```bash
rtk git status --short
rtk git diff --check
rtk git ls-files dist .build .DS_Store
```
Outcomes:
- `git status --short` showed the expected pre-existing unrelated theme/playback/testing work plus Task 5 files before commit.
- `git diff --check` exited `0` with no output.
- `git ls-files dist .build .DS_Store` exited `0` with no output.
- After commit, `git status --short` still showed only the pre-existing unrelated uncommitted work; Task 5 files were cleanly committed.

## Commit
Auth handling:
- Switched GitHub CLI auth to `d-stash` before staging/commit.
- Restored active auth to `dpandey_varonis` afterward.

Committed as:
- Commit: `a511f801eb5eeba62e882d365f0930212ac56707`
- Message: `ci: verify public app packaging`

## Self-review
- Workflow covers all required validation areas with minimal read-only GitHub permissions.
- SwiftPM safety override is scoped to the commands that need it.
- Existing packaging/installer semantics were preserved; only invocation environment and test-suite serialization were tightened for reliability.
- Only Task 5 files were staged and committed; pre-existing unrelated work remained untouched.

## Concerns
- Manual System Settings verification for Launch at Login still must be performed on a real desktop session.
- During debugging, running packaging and installer checks concurrently caused local `.build/iconset` contention; final CI/workflow sequence is serial, so the committed workflow avoids that issue.

## Fix round 1 — remove `rtk` from public workflow

### Root cause
- `.github/workflows/ci.yml` committed GitHub Actions `run:` commands prefixed with `rtk`.
- `rtk` is available in this assistant session, but not on GitHub-hosted macOS runners.
- That makes the workflow fail immediately before any real CI work starts.

### Files changed
- `.github/workflows/ci.yml`
- `Tests/WorkflowChecks.sh`
- `.superpowers/sdd/2026-09-19-public-packaging/task-5-report.md`

### Static validation added
Added `Tests/WorkflowChecks.sh`:
- fails if `.github/workflows/ci.yml` contains `rtk`
- prints `Workflow checks passed` otherwise

### Red/green proof
Red command:
```bash
rtk bash Tests/WorkflowChecks.sh
```
Red outcome:
- Exit `1`
- matched lines:
  - `24:        run: rtk bash -n setup.sh scripts/*.sh Tests/*.sh`
  - `31:            rtk swift test --no-parallel`
  - `35:          rtk mkdir -p .build/ci-checks`
  - `36:          rtk swiftc Sources/echofloat/Theming/Theme.swift \`
  - `40:          rtk .build/ci-checks/theme-checks`
  - `44:          rtk mkdir -p .build/ci-checks`
  - `45:          rtk swiftc Sources/echofloat/Models/TrackSignature.swift \`
  - `50:          rtk .build/ci-checks/playback-checks`
  - `53:        run: rtk bash Tests/PackagingChecks.sh`
  - `56:        run: rtk bash Tests/InstallerChecks.sh`
- final stderr: `GitHub Actions workflow must not depend on rtk.`

Green change:
- replaced workflow `rtk` commands with stock `bash`, `swift`, `swiftc`, `mkdir`, and executable invocations
- added explicit workflow validation CI step:
  - `bash Tests/WorkflowChecks.sh`

### Fix-round validation commands and exact outcomes
1. Shell syntax
```bash
rtk bash -n setup.sh scripts/*.sh Tests/*.sh
```
- Exit `0`
- No output

2. Workflow static validation
```bash
rtk bash Tests/WorkflowChecks.sh
```
- Exit `0`
- Output: `Workflow checks passed`

3. Workflow YAML parse
```bash
rtk proxy ruby -e "require 'yaml'; YAML.load_file('.github/workflows/ci.yml'); puts 'workflow yaml ok'"
```
- Exit `0`
- Output: `workflow yaml ok`

4. Swift tests
```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all rtk swift test --no-parallel
```
- Exit `0`
- `35` tests passed

5. Standalone animation checks
```bash
rtk mkdir -p .build/ci-local-checks && \
rtk swiftc Sources/echofloat/Theming/Theme.swift \
  Sources/echofloat/Theming/ThemeAnimation.swift \
  Tests/ThemeAnimationChecks.swift \
  -o .build/ci-local-checks/theme-checks && \
rtk .build/ci-local-checks/theme-checks
```
- Exit `0`
- No output

6. Standalone playback timing checks
```bash
rtk mkdir -p .build/ci-local-checks && \
rtk swiftc Sources/echofloat/Models/TrackSignature.swift \
  Sources/echofloat/Models/NowPlayingState.swift \
  Sources/echofloat/Playback/PlaybackClock.swift \
  Tests/PlaybackTimingChecks.swift \
  -o .build/ci-local-checks/playback-checks && \
rtk .build/ci-local-checks/playback-checks
```
- Exit `0`
- No output

7. Packaging checks
```bash
rtk bash Tests/PackagingChecks.sh
```
- Exit `0`
- Final line: `Packaging checks passed`

8. Installer lifecycle checks
```bash
rtk bash Tests/InstallerChecks.sh
```
- Exit `0`
- Final line: `Installer checks passed`

9. Artifact boundary checks
```bash
rtk git diff --check
rtk git ls-files dist .build .DS_Store
```
- Both exited `0`
- No output

### Notes
- An initial parallel local rerun of packaging + installer checks reproduced existing `.build/iconset` contention in this shared worktree. Final recorded packaging and installer validations above were rerun sequentially and both passed.
- No manual Launch-at-Login UI actions were performed in this fix round.
