# Sparkle Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let anyone who has already installed Echofloat check for and install the latest release from inside the app, without notarization or an Apple Developer Program membership.

**Architecture:** Integrate the Sparkle 2 framework (SwiftPM dependency) with a `SPUStandardUpdaterController` wired into the existing app-delegate/menu-bar wiring, behind a small `UpdateChecking` protocol so the menu bar controller stays unit-testable the same way it already is for `LoginItemServicing`. Releases are built and signed by a new GitHub Actions workflow triggered on `v*` tags, reusing the existing `scripts/package-app.sh`, then published as a GitHub Release plus an `appcast.xml` hosted on the `gh-pages` branch that Sparkle polls.

**Tech Stack:** Swift 5.9/6.1 (SwiftPM), AppKit, Sparkle 2.10.0, bash, GitHub Actions, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-09-25-auto-update-design.md`

## Global Constraints

- Sparkle version: pin to `2.10.0` (exact) in both package manifests.
- No Apple Developer ID signing or notarization is introduced by this plan — apps stay ad-hoc signed, per the spec's explicit out-of-scope list.
- The Sparkle private signing key must never be committed to the repository; it lives only in the `SPARKLE_PRIVATE_KEY` GitHub Actions secret.
- Follow existing repo conventions: shell scripts use `set -euo pipefail`, resolve `ROOT` via `dirname "${BASH_SOURCE[0]}"`, and are exercised by a `Tests/*Checks.sh` script wired into `.github/workflows/ci.yml`.
- Swift changes are covered by Swift Testing (`@Test`/`#expect`) tests under `Tests/echofloatTests`, following the existing `StatusItemControllerTests.swift` style (reflection via `Mirror` to reach private properties, menu items located by title).

---

### Task 1: Generate the Sparkle EdDSA signing key pair (manual, one-time)

This task has no automated test — it is a one-time interactive action a human with repository admin access must perform. Do not attempt to script around it or fabricate a key pair.

**Files:**
- Create: `Resources/SparklePublicKey.txt` (public key only — safe to commit)

- [ ] **Step 1: Download Sparkle's command-line tools**

Sparkle's `generate_keys` tool ships in the binary release archive, not through SwiftPM. Download and extract it:

```bash
curl -L -o /tmp/Sparkle-2.10.0.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz
mkdir -p /tmp/sparkle-tools
tar -xf /tmp/Sparkle-2.10.0.tar.xz -C /tmp/sparkle-tools
```

- [ ] **Step 2: Generate the key pair**

```bash
/tmp/sparkle-tools/bin/generate_keys
```

This prints the public key to the terminal and stores the private key in the local macOS keychain (item name `Private key for signing Sparkle updates`). If a key already exists, the tool prints the existing public key instead of creating a new one — do not run this on more than one machine for the same project.

- [ ] **Step 3: Export the private key for CI**

```bash
/tmp/sparkle-tools/bin/generate_keys -x /tmp/sparkle_private_key.pem
```

- [ ] **Step 4: Store the private key as a GitHub Actions secret**

```bash
gh secret set SPARKLE_PRIVATE_KEY --repo d-stash/echofloat < /tmp/sparkle_private_key.pem
rm -f /tmp/sparkle_private_key.pem
```

- [ ] **Step 5: Commit the public key**

Paste the public key printed in Step 2 (a single base64 line) into a new file:

```bash
cat > Resources/SparklePublicKey.txt <<'EOF'
<paste the public key here, no surrounding quotes or whitespace>
EOF
git add Resources/SparklePublicKey.txt
git commit -m "chore: add Sparkle EdDSA public key"
```

- [ ] **Step 6: Clean up local tool download**

```bash
rm -rf /tmp/sparkle-tools /tmp/Sparkle-2.10.0.tar.xz
```

---

### Task 2: Add the Sparkle SwiftPM dependency

**Files:**
- Modify: `Package.swift`
- Modify: `Package@swift-6.1.swift`

**Interfaces:**
- Produces: the `Sparkle` SwiftPM product available to `import Sparkle` in the `echofloat` target, used by Task 3.

- [ ] **Step 1: Add the dependency to `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "echofloat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "echofloat", targets: ["echofloat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "echofloat",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
    ]
)
```

- [ ] **Step 2: Add the same dependency to `Package@swift-6.1.swift`**

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "echofloat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "echofloat", targets: ["echofloat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            exact: "6.2.4"
        ),
    ],
    targets: [
        .executableTarget(
            name: "echofloat",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "echofloatTests",
            dependencies: [
                "echofloat",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
```

- [ ] **Step 3: Verify the package resolves and builds**

Run: `swift build`
Expected: Sparkle resolves into `Package.resolved` (Sparkle 2 has no further SPM dependencies of its own) and the build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Package.swift "Package@swift-6.1.swift" Package.resolved
git commit -m "build: add Sparkle 2.10.0 dependency"
```

---

### Task 3: Wire `SPUStandardUpdaterController` into the app, behind a testable protocol

**Files:**
- Create: `Sources/echofloat/Support/UpdateChecking.swift`
- Modify: `Sources/echofloat/App/AppDelegate.swift`
- Modify: `Resources/Info.plist`
- Test: `Tests/echofloatTests/UpdateCheckingTests.swift`

**Interfaces:**
- Consumes: `Resources/SparklePublicKey.txt` (Task 1, read only by humans/docs — the plist value is set by hand in this task, not read at runtime).
- Produces: `protocol UpdateChecking: AnyObject { func checkForUpdates(_ sender: Any?); var automaticallyChecksForUpdates: Bool { get set } }`, and `final class NoopUpdateChecker: UpdateChecking` (default used where no real updater is supplied). Task 4 consumes both.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/echofloatTests/UpdateCheckingTests.swift
import Testing
@testable import echofloat

private final class RecordingUpdateChecker: UpdateChecking {
    var automaticallyChecksForUpdates = true
    var checkForUpdatesCallCount = 0

    func checkForUpdates(_ sender: Any?) {
        checkForUpdatesCallCount += 1
    }
}

@Test func recordingCheckerCountsInvocations() {
    let checker = RecordingUpdateChecker()
    checker.checkForUpdates(nil)
    checker.checkForUpdates(nil)
    #expect(checker.checkForUpdatesCallCount == 2)
}

@Test func noopUpdateCheckerIsInertAndDoesNotCrash() {
    let checker = NoopUpdateChecker()
    checker.checkForUpdates(nil)
    checker.automaticallyChecksForUpdates = false
    #expect(checker.automaticallyChecksForUpdates == false)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter UpdateCheckingTests`
Expected: FAIL — `UpdateChecking`/`NoopUpdateChecker` not defined.

- [ ] **Step 3: Implement `UpdateChecking`**

```swift
// Sources/echofloat/Support/UpdateChecking.swift
import Sparkle

/// Thin seam over Sparkle's updater so menu-bar wiring can be unit tested
/// without a real Sparkle instance (which needs a signed appcast feed and
/// network access). Mirrors the `LoginItemServicing` pattern already used
/// for `AutostartManager`.
protocol UpdateChecking: AnyObject {
    func checkForUpdates(_ sender: Any?)
    var automaticallyChecksForUpdates: Bool { get set }
}

extension SPUStandardUpdaterController: UpdateChecking {
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }
}

/// Default used by call sites (and most existing tests) that don't care
/// about update checking, so adding this dependency doesn't force every
/// `StatusItemController` construction site to supply a real updater.
final class NoopUpdateChecker: UpdateChecking {
    var automaticallyChecksForUpdates = false
    func checkForUpdates(_ sender: Any?) {}
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter UpdateCheckingTests`
Expected: PASS

- [ ] **Step 5: Wire the real updater into `AppDelegate`**

```swift
// Sources/echofloat/App/AppDelegate.swift
import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var overlayController: OverlayWindowController?
    private var viewModel: PlayerViewModel?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // MediaRemote (private framework) is locked to Apple-signed processes only as of
        // macOS Sonoma 15.3+, so third-party detection now goes through public Distributed
        // Notifications (Music.app, Spotify) plus AppleScript/JS tab scraping (YouTube Music).
        let musicSource = CompositeNowPlayingSource(sources: [
            DistributedNowPlayingSource(),
            BrowserNowPlayingSource()
        ])
        let cacheDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Echofloat/LyricsCache", isDirectory: true)
        let cache = LyricsCache(directory: cacheDirectory)
        let lyricsProvider = LRCLibProvider()

        let vm = PlayerViewModel(musicSource: musicSource, lyricsProvider: lyricsProvider, cache: cache)
        vm.start()
        viewModel = vm

        let themeManager = ThemeManager()
        let fontSizeManager = FontSizeManager()
        let overlay = OverlayWindowController(viewModel: vm, themeManager: themeManager, fontSizeManager: fontSizeManager)
        overlay.start()
        overlayController = overlay

        let autostartManager = AutostartManager()
        do {
            try autostartManager.removeLegacyLaunchAgent()
        } catch {
            NSLog("Echofloat: Could not remove legacy login item: \(error.localizedDescription)")
        }

        let updater = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = updater

        statusItemController = StatusItemController(
            themeManager: themeManager,
            fontSizeManager: fontSizeManager,
            overlayController: overlay,
            autostartManager: autostartManager,
            updateChecker: updater
        )
    }
}
```

- [ ] **Step 6: Add the Sparkle Info.plist keys**

Edit `Resources/Info.plist`, adding these keys inside the top-level `<dict>` (alphabetical position next to the other `SU`-prefixed... there are none yet, so add after `NSHighResolutionCapable`):

```xml
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://d-stash.github.io/echofloat/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>REPLACE_WITH_CONTENTS_OF_Resources_SparklePublicKey.txt</string>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
```

Immediately after saving, replace `REPLACE_WITH_CONTENTS_OF_Resources_SparklePublicKey.txt` with the exact contents of `Resources/SparklePublicKey.txt` from Task 1 — the plist value must match byte-for-byte or Sparkle will reject every update as unsigned.

- [ ] **Step 7: Verify packaging still lints**

Run: `bash Tests/PackagingChecks.sh`
Expected: PASS (this script already asserts `plutil -lint`, so a malformed plist edit fails loudly here).

- [ ] **Step 8: Commit**

```bash
git add Sources/echofloat/Support/UpdateChecking.swift Sources/echofloat/App/AppDelegate.swift \
  Resources/Info.plist Tests/echofloatTests/UpdateCheckingTests.swift
git commit -m "feat: wire Sparkle updater into app delegate"
```

---

### Task 4: Add "Check for Updates…" to the menu bar

**Files:**
- Modify: `Sources/echofloat/MenuBar/StatusItemController.swift`
- Test: `Tests/echofloatTests/StatusItemControllerTests.swift`

**Interfaces:**
- Consumes: `protocol UpdateChecking` and `final class NoopUpdateChecker` (Task 3).
- Produces: `StatusItemController.init(..., updateChecker: UpdateChecking = NoopUpdateChecker())` — Task 3's `AppDelegate` wiring already relies on this exact parameter name and default.

- [ ] **Step 1: Write the failing test**

Append to `Tests/echofloatTests/StatusItemControllerTests.swift` (reuses the existing private helpers `makeStatusItemTestDirectory` and `reflectedStatusItem`):

```swift
private final class RecordingUpdateChecker: UpdateChecking {
    var automaticallyChecksForUpdates = true
    var checkForUpdatesCallCount = 0

    func checkForUpdates(_ sender: Any?) {
        checkForUpdatesCallCount += 1
    }
}

private func checkForUpdatesMenuItem(in menu: NSMenu) -> NSMenuItem? {
    menu.items.first { $0.title == "Check for Updates…" }
}

@Test @MainActor func checkForUpdatesMenuItemInvokesUpdateChecker() throws {
    _ = NSApplication.shared
    let service = MutableLoginItemService()
    let cacheDirectory = try makeStatusItemTestDirectory()
    defer { try? FileManager.default.removeItem(at: cacheDirectory.deletingLastPathComponent()) }

    let viewModel = PlayerViewModel(
        musicSource: SilentMusicSource(),
        lyricsProvider: NeverLyricsProvider(),
        cache: LyricsCache(directory: cacheDirectory)
    )
    let themeDefaults = try #require(UserDefaults(suiteName: "StatusItemUpdateTests.\(UUID().uuidString)"))
    let overlayDefaults = try #require(UserDefaults(suiteName: "StatusItemUpdateTests.overlay.\(UUID().uuidString)"))
    let themeManager = ThemeManager(defaults: themeDefaults)
    let fontSizeManager = FontSizeManager(defaults: overlayDefaults)
    let updateChecker = RecordingUpdateChecker()
    let controller = StatusItemController(
        themeManager: themeManager,
        fontSizeManager: fontSizeManager,
        overlayController: OverlayWindowController(
            viewModel: viewModel,
            themeManager: themeManager,
            fontSizeManager: fontSizeManager,
            defaults: overlayDefaults
        ),
        autostartManager: AutostartManager(service: service),
        updateChecker: updateChecker
    )

    let statusItem = try #require(reflectedStatusItem(from: controller))
    defer { NSStatusBar.system.removeStatusItem(statusItem) }
    let menu = try #require(statusItem.menu)
    let item = try #require(checkForUpdatesMenuItem(in: menu))

    _ = item.target?.perform(item.action, with: item)

    #expect(updateChecker.checkForUpdatesCallCount == 1)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter checkForUpdatesMenuItemInvokesUpdateChecker`
Expected: FAIL — extra `updateChecker:` argument does not exist on `StatusItemController.init`, and no menu item titled "Check for Updates…" exists.

- [ ] **Step 3: Add the parameter and menu item**

In `Sources/echofloat/MenuBar/StatusItemController.swift`:

```swift
    private let overlayController: OverlayWindowController
    private let autostartManager: AutostartManager
    private let updateChecker: UpdateChecking
    private let approvalPresenter: @MainActor () -> Void
    private let menu = NSMenu()
    private let visibilityItem = NSMenuItem(title: "", action: #selector(toggleOverlayVisibility), keyEquivalent: "")
    private let themeMenu = NSMenu()
    private let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
    private let fontSizeMenu = NSMenu()
    private let fontSizeItem = NSMenuItem(title: "Font Size", action: nil, keyEquivalent: "")
    private let increaseFontSizeItem = NSMenuItem(title: "Increase Font Size", action: #selector(increaseFontSize), keyEquivalent: "=")
    private let decreaseFontSizeItem = NSMenuItem(title: "Decrease Font Size", action: #selector(decreaseFontSize), keyEquivalent: "-")
    private let displayModeItem = NSMenuItem(title: "Show on Active Display Only", action: #selector(toggleDisplayMode), keyEquivalent: "")
    private let autostartItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleAutostart), keyEquivalent: "")
    private let checkForUpdatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit Echofloat", action: #selector(quit), keyEquivalent: "q")

    init(
        themeManager: ThemeManager,
        fontSizeManager: FontSizeManager,
        overlayController: OverlayWindowController,
        autostartManager: AutostartManager,
        updateChecker: UpdateChecking = NoopUpdateChecker(),
        approvalPresenter: @escaping @MainActor () -> Void = StatusItemController.presentApprovalGuidance
    ) {
        self.themeManager = themeManager
        self.fontSizeManager = fontSizeManager
        self.overlayController = overlayController
        self.autostartManager = autostartManager
        self.updateChecker = updateChecker
        self.approvalPresenter = approvalPresenter
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Echofloat")
        configureMenu()
        refreshMenuState()
    }
```

Then in `configureMenu()`, add the item just above the quit separator:

```swift
        autostartItem.target = self
        menu.addItem(autostartItem)

        menu.addItem(.separator())

        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        quitItem.target = self
        menu.addItem(quitItem)
```

And add the action method near the other `@objc` handlers:

```swift
    @objc private func checkForUpdates() {
        updateChecker.checkForUpdates(nil)
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter checkForUpdatesMenuItemInvokesUpdateChecker`
Expected: PASS

- [ ] **Step 5: Run the full test suite to confirm no regressions**

Run: `swift test --no-parallel`
Expected: PASS (existing `StatusItemControllerTests` cases still pass since `updateChecker` has a default value).

- [ ] **Step 6: Commit**

```bash
git add Sources/echofloat/MenuBar/StatusItemController.swift Tests/echofloatTests/StatusItemControllerTests.swift
git commit -m "feat(menu-bar): add Check for Updates menu item"
```

---

### Task 5: Add the release packaging/signing script

**Files:**
- Create: `scripts/publish-release.sh`
- Create: `scripts/appcast-template.xml`
- Test: `Tests/ReleaseScriptChecks.sh`

**Interfaces:**
- Consumes: `scripts/package-app.sh --output-dir <dir>` (existing, unchanged), `VERSION` file (existing).
- Produces: given `--sparkle-tools-dir <dir>` (containing `bin/sign_update`) and `--output-dir <dir>`, writes `<dir>/Echofloat-<version>.zip` and `<dir>/appcast.xml`. A `--dry-run` flag skips invoking `sign_update` and instead writes a fixed placeholder signature, so Task 6/CI and local tests can exercise the script without real keys.

- [ ] **Step 1: Write the failing test**

```bash
# Tests/ReleaseScriptChecks.sh
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$ROOT/.build/release-script-tests"
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT

GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.bareRepository \
GIT_CONFIG_VALUE_0=all \
    "$ROOT/scripts/publish-release.sh" --output-dir "$TMP_ROOT" --dry-run

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ZIP="$TMP_ROOT/Echofloat-$VERSION.zip"
APPCAST="$TMP_ROOT/appcast.xml"

test -f "$ZIP"
test -f "$APPCAST"
grep -q "Echofloat-$VERSION.zip" "$APPCAST"
grep -q "sparkle:version=\"$VERSION\"" "$APPCAST"
grep -q "sparkle:edSignature=\"dry-run-placeholder-signature\"" "$APPCAST"
xmllint --noout "$APPCAST"

echo "Release script checks passed"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash Tests/ReleaseScriptChecks.sh`
Expected: FAIL — `scripts/publish-release.sh: No such file or directory`.

- [ ] **Step 3: Write the appcast template**

```xml
<!-- scripts/appcast-template.xml -->
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Echofloat</title>
        <item>
            <title>Version __VERSION__</title>
            <pubDate>__PUB_DATE__</pubDate>
            <sparkle:version>__VERSION__</sparkle:version>
            <sparkle:shortVersionString>__VERSION__</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <enclosure
                url="__DOWNLOAD_URL__"
                sparkle:version="__VERSION__"
                sparkle:edSignature="__SIGNATURE__"
                length="__LENGTH__"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
```

This is a single-item appcast (only the latest release) — sufficient for Sparkle's update check, and avoids having to retain every historical release archive just to keep old entries valid.

- [ ] **Step 4: Write `scripts/publish-release.sh`**

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT/dist"
SPARKLE_TOOLS_DIR=""
DRY_RUN=false
DOWNLOAD_URL_BASE="https://github.com/d-stash/echofloat/releases/download"

while (($#)); do
    case "$1" in
        --output-dir)
            test $# -ge 2 || { echo "Missing value for --output-dir" >&2; exit 64; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --sparkle-tools-dir)
            test $# -ge 2 || { echo "Missing value for --sparkle-tools-dir" >&2; exit 64; }
            SPARKLE_TOOLS_DIR="$2"
            shift 2
            ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 64 ;;
    esac
done

if ! $DRY_RUN && [[ -z "$SPARKLE_TOOLS_DIR" ]]; then
    echo "--sparkle-tools-dir is required unless --dry-run is set" >&2
    exit 64
fi

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "VERSION must use semantic version format, for example 0.1.0." >&2
    exit 1
}

mkdir -p "$OUTPUT_DIR"
"$ROOT/scripts/package-app.sh" --output-dir "$OUTPUT_DIR"

APP="$OUTPUT_DIR/Echofloat.app"
ZIP="$OUTPUT_DIR/Echofloat-$VERSION.zip"
rm -f "$ZIP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
LENGTH="$(stat -f%z "$ZIP")"

if $DRY_RUN; then
    SIGNATURE="dry-run-placeholder-signature"
else
    SIGNATURE="$("$SPARKLE_TOOLS_DIR/bin/sign_update" "$ZIP" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
    test -n "$SIGNATURE" || { echo "sign_update did not produce a signature" >&2; exit 1; }
fi

DOWNLOAD_URL="$DOWNLOAD_URL_BASE/v$VERSION/Echofloat-$VERSION.zip"
PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

sed \
    -e "s|__VERSION__|$VERSION|g" \
    -e "s|__PUB_DATE__|$PUB_DATE|g" \
    -e "s|__DOWNLOAD_URL__|$DOWNLOAD_URL|g" \
    -e "s|__SIGNATURE__|$SIGNATURE|g" \
    -e "s|__LENGTH__|$LENGTH|g" \
    "$ROOT/scripts/appcast-template.xml" > "$OUTPUT_DIR/appcast.xml"

echo "Published release artifacts to $OUTPUT_DIR"
```

- [ ] **Step 5: Make it executable and run the test**

Run:
```bash
chmod +x scripts/publish-release.sh
bash Tests/ReleaseScriptChecks.sh
```
Expected: PASS. If `xmllint` is missing locally, install it via Xcode Command Line Tools (it ships with macOS) — do not remove the check.

- [ ] **Step 6: Add the check to CI**

In `.github/workflows/ci.yml`, add a step after "Verify app packaging":

```yaml
      - name: Verify release script
        run: bash Tests/ReleaseScriptChecks.sh
```

- [ ] **Step 7: Add the check to `CONTRIBUTING.md`'s local-checks list**

```markdown
```bash
swift build
bash Tests/PackagingChecks.sh
bash Tests/InstallerChecks.sh
bash Tests/ReleaseScriptChecks.sh
```
```

- [ ] **Step 8: Commit**

```bash
git add scripts/publish-release.sh scripts/appcast-template.xml Tests/ReleaseScriptChecks.sh \
  .github/workflows/ci.yml CONTRIBUTING.md
git commit -m "feat(release): add publish-release.sh and appcast generation"
```

---

### Task 6: Add the tag-triggered release GitHub Actions workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `scripts/publish-release.sh --output-dir <dir> --sparkle-tools-dir <dir>` (Task 5), `SPARKLE_PRIVATE_KEY` secret (Task 1).

- [ ] **Step 1: Write the workflow**

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write
  pages: write
  id-token: write

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  publish:
    runs-on: macos-15
    timeout-minutes: 20

    steps:
      - uses: actions/checkout@v4

      - name: Validate tag matches VERSION file
        run: |
          TAG="${GITHUB_REF_NAME#v}"
          FILE_VERSION="$(tr -d '[:space:]' < VERSION)"
          if [[ "$TAG" != "$FILE_VERSION" ]]; then
            echo "Tag v$TAG does not match VERSION file ($FILE_VERSION)" >&2
            exit 1
          fi

      - name: Download Sparkle CLI tools
        run: |
          curl -L -o /tmp/Sparkle-2.10.0.tar.xz \
            https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz
          mkdir -p /tmp/sparkle-tools
          tar -xf /tmp/Sparkle-2.10.0.tar.xz -C /tmp/sparkle-tools

      - name: Import Sparkle private key
        env:
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        run: |
          echo "$SPARKLE_PRIVATE_KEY" | /tmp/sparkle-tools/bin/generate_keys -f -

      - name: Build, sign, and generate appcast
        run: |
          GIT_CONFIG_COUNT=1 \
          GIT_CONFIG_KEY_0=safe.bareRepository \
          GIT_CONFIG_VALUE_0=all \
            bash scripts/publish-release.sh --output-dir dist --sparkle-tools-dir /tmp/sparkle-tools

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          VERSION="$(tr -d '[:space:]' < VERSION)"
          gh release create "v$VERSION" \
            "dist/Echofloat-$VERSION.zip" \
            --title "Echofloat $VERSION" \
            --generate-notes

      - name: Publish appcast to gh-pages
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git fetch origin gh-pages || true
          git worktree add /tmp/gh-pages gh-pages 2>/dev/null || {
            git worktree add -B gh-pages /tmp/gh-pages origin/main
            (cd /tmp/gh-pages && git rm -rf . >/dev/null 2>&1 || true)
          }
          cp dist/appcast.xml /tmp/gh-pages/appcast.xml
          cd /tmp/gh-pages
          git add appcast.xml
          git commit -m "chore: publish appcast for ${{ github.ref_name }}" || echo "Nothing to commit"
          git push origin gh-pages
```

- [ ] **Step 2: Validate the workflow file syntactically**

Run: `bash -n <(yq -r '.jobs.publish.steps[].run // empty' .github/workflows/release.yml 2>/dev/null) || true`

Since that's a soft check, at minimum confirm the YAML parses:

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
Expected: no output, exit code 0.

- [ ] **Step 3: Add it to the existing shell-validation CI step's scope**

`.github/workflows/ci.yml`'s "Validate shell scripts" step runs `bash -n setup.sh scripts/*.sh Tests/*.sh` — this workflow's embedded `run:` blocks are not covered by that, which is consistent with how `ci.yml`'s own embedded steps are not self-validated either. No change needed here.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add tag-triggered Sparkle release workflow"
```

- [ ] **Step 5: One-time manual repo setup (not automatable from this session)**

After merging, a repository admin must:
1. Enable GitHub Pages for the `gh-pages` branch (Settings → Pages → Source: Deploy from branch → `gh-pages` / root).
2. Confirm `Resources/Info.plist`'s `SUFeedURL` (`https://d-stash.github.io/echofloat/appcast.xml`) matches the Pages URL GitHub assigns.
3. Push a `v0.1.1`-style tag once ready to test the pipeline end-to-end, per the spec's Testing section.

---

### Task 7: Update user-facing docs

**Files:**
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- None — documentation only.

- [ ] **Step 1: Update the README "Update" section**

Replace:

```markdown
## Update

Run the installer again:

```bash
./setup.sh
```
```

with:

```markdown
## Update

Echofloat checks for updates automatically and lets you install them from the menu bar (Echofloat menu > Check for Updates…).

Building from source instead? Pull the latest changes and reinstall:

```bash
git pull
./setup.sh
```
```

- [ ] **Step 2: Update the "Limitations and roadmap" bullet**

Replace:

```markdown
- The current release is source-built locally; there is no downloadable notarized binary.
```

with:

```markdown
- Releases are signed for Sparkle auto-update (EdDSA), not with an Apple Developer ID — first install still requires right-click > Open once, the same as before.
```

- [ ] **Step 3: Add a "Cutting a release" section to `CONTRIBUTING.md`**

Insert before the `## Notes` section:

```markdown
## Cutting a release

1. Bump `VERSION` (semantic version, e.g. `0.2.0`) and commit.
2. Tag and push: `git tag v0.2.0 && git push origin v0.2.0`.
3. The `Release` GitHub Actions workflow builds, signs, and publishes the release automatically — see `.github/workflows/release.yml`.
4. Confirm the new version appears at the `SUFeedURL` in `Resources/Info.plist` before announcing.
```

- [ ] **Step 4: Commit**

```bash
git add README.md CONTRIBUTING.md
git commit -m "docs: describe Sparkle auto-update and release process"
```

---

## Self-Review Notes

- **Spec coverage:** key generation (Task 1), SwiftPM dependency (Task 2), updater wiring + Info.plist (Task 3), menu item (Task 4), CI release pipeline + appcast (Tasks 5-6), docs (Task 7). All spec sections have a task.
- **Manual steps called out:** Task 1 (key generation) and Task 6 Step 5 (Pages enablement, first real tag) require a human with repo/secret access — flagged explicitly rather than hidden inside automated steps.
- **Type/name consistency:** `UpdateChecking` / `NoopUpdateChecker` (Task 3) are the exact names consumed by `StatusItemController.init(updateChecker:)` (Task 4) and `AppDelegate` (Task 3 Step 5).
