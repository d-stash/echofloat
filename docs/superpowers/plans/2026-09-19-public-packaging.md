# Echofloat Public Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a polished clone-to-running-app workflow for public macOS users through a native `.app` bundle, one-command local installer, modern Launch at Login support, documentation, and CI.

**Architecture:** Keep SwiftPM as the only build system. Repository scripts build the release executable, assemble and validate a conventional app bundle, install it under `~/Applications`, and uninstall it without elevated privileges. Replace the legacy LaunchAgent writer with an injectable wrapper around `SMAppService.mainApp`, then document and continuously verify the complete workflow.

**Tech Stack:** Swift 5.9+, SwiftPM, AppKit, ServiceManagement, Swift Testing 6.2.4, POSIX shell, `plutil`, `codesign`, `iconutil`, GitHub Actions macOS runners

**Spec:** `docs/superpowers/specs/2026-09-19-public-packaging-design.md`

## Global Constraints

- Support macOS 13 Ventura or newer.
- Support native builds on Apple Silicon and Intel Macs.
- Require only Apple Command Line Tools; do not require full Xcode or a third-party project generator.
- Install to `~/Applications/Echofloat.app` by default without `sudo`.
- Use bundle identifier `com.echofloat.app`.
- Keep the app agent-only with `LSUIElement = true`.
- Declare `NSAppleEventsUsageDescription`.
- Do not bypass Gatekeeper, clear quarantine attributes, modify system security settings, or write global Git configuration.
- Do not publish or claim support for a downloadable prebuilt binary in this phase.
- Do not collect browser session tokens, telemetry, or analytics.
- Preserve existing user preferences and lyrics cache during install/update.
- Use only repository-owned artwork and documentation.

---

### Task 1: Bundle Metadata and Native Packaging

**Files:**
- Create: `VERSION`
- Create: `Resources/Info.plist`
- Create: `Resources/AppIcon.svg`
- Create: `Resources/AppIcon.icns`
- Create: `scripts/generate-icon.sh`
- Create: `scripts/package-app.sh`
- Create: `Tests/PackagingChecks.sh`
- Modify: `.gitignore`
- Modify: `Package.swift`

**Interfaces:**
- Produces: `scripts/package-app.sh [--skip-build] [--output-dir PATH]`
- Produces: `dist/Echofloat.app`
- Produces: stable bundle identifier `com.echofloat.app`
- Consumes: SwiftPM executable product `echofloat`

- [ ] **Step 1: Write the failing packaging check**

Create `Tests/PackagingChecks.sh`:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR%/}/echofloat-packaging-tests.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

"$ROOT/scripts/package-app.sh" --output-dir "$TMP_ROOT"

APP="$TMP_ROOT/Echofloat.app"
PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/echofloat"

test -d "$APP"
test -x "$EXECUTABLE"
test -f "$APP/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$PLIST"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" = "com.echofloat.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")" = "echofloat"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")" = "13.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$PLIST")" = "true"
test -n "$(/usr/libexec/PlistBuddy -c 'Print :NSAppleEventsUsageDescription' "$PLIST")"
/usr/bin/codesign --verify --deep --strict "$APP"

echo "Packaging checks passed"
```

- [ ] **Step 2: Run the check to verify it fails**

Run:

```bash
bash Tests/PackagingChecks.sh
```

Expected: FAIL because `scripts/package-app.sh` does not exist.

- [ ] **Step 3: Add stable package metadata**

Create `VERSION`:

```text
0.1.0
```

Create `Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Echofloat</string>
    <key>CFBundleExecutable</key>
    <string>echofloat</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.echofloat.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Echofloat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Echofloat reads and controls your active supported music player to display synchronized lyrics.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

Update `Package.swift` with public package metadata while retaining the existing executable and test targets:

```swift
let package = Package(
    name: "echofloat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "echofloat", targets: ["echofloat"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            exact: "6.2.4"
        ),
    ],
    targets: [
        .executableTarget(name: "echofloat"),
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

- [ ] **Step 4: Add repository-owned app icon source and generator**

Create `Resources/AppIcon.svg` as original repository-owned artwork:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="background" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0b1027"/>
      <stop offset="1" stop-color="#411052"/>
    </linearGradient>
    <linearGradient id="wave" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#55e7ff"/>
      <stop offset="1" stop-color="#ff4ed7"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="220" fill="url(#background)"/>
  <rect x="164" y="340" width="696" height="344" rx="172"
        fill="#080b18" fill-opacity=".78" stroke="#ffffff" stroke-opacity=".12" stroke-width="8"/>
  <rect x="360" y="446" width="56" height="132" rx="28" fill="url(#wave)"/>
  <rect x="484" y="402" width="56" height="220" rx="28" fill="url(#wave)"/>
  <rect x="608" y="458" width="56" height="108" rx="28" fill="url(#wave)"/>
</svg>
```

Create `scripts/generate-icon.sh`:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/Resources/AppIcon.svg"
ICONSET="$(mktemp -d "${TMPDIR%/}/echofloat-iconset.XXXXXX")/AppIcon.iconset"
trap 'rm -rf "$(dirname "$ICONSET")"' EXIT
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    /usr/bin/sips -s format png -z "$size" "$size" "$SOURCE" \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    /usr/bin/sips -s format png -z "$double" "$double" "$SOURCE" \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
echo "Generated Resources/AppIcon.icns"
```

Run:

```bash
chmod +x scripts/generate-icon.sh
scripts/generate-icon.sh
```

Expected: `Resources/AppIcon.icns` exists and `sips -g pixelWidth -g pixelHeight Resources/AppIcon.icns` succeeds.

- [ ] **Step 5: Implement the app-bundle packager**

Create `scripts/package-app.sh` with:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT/dist"
SKIP_BUILD=false

while (($#)); do
    case "$1" in
        --skip-build) SKIP_BUILD=true; shift ;;
        --output-dir)
            test $# -ge 2 || { echo "Missing value for --output-dir" >&2; exit 64; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *) echo "Unknown argument: $1" >&2; exit 64 ;;
    esac
done

test "$(uname -s)" = "Darwin" || { echo "Echofloat requires macOS." >&2; exit 1; }
for tool in swift plutil codesign ditto; do
    command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "VERSION must use semantic version format, for example 0.1.0." >&2
    exit 1
}

cd "$ROOT"
if ! $SKIP_BUILD; then
    swift build -c release --product echofloat
fi
BIN_DIR="$(swift build -c release --show-bin-path)"
test -x "$BIN_DIR/echofloat" || {
    echo "Release executable not found. Run without --skip-build." >&2
    exit 1
}

WORK_DIR="$(mktemp -d "${TMPDIR%/}/echofloat-package.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
APP="$WORK_DIR/Echofloat.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/ditto "$BIN_DIR/echofloat" "$APP/Contents/MacOS/echofloat"
/usr/bin/ditto "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/bin/ditto "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod 755 "$APP/Contents/MacOS/echofloat"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"

mkdir -p "$OUTPUT_DIR"
TARGET="$OUTPUT_DIR/Echofloat.app"
if [[ -e "$TARGET" && "$TARGET" != */Echofloat.app ]]; then
    echo "Refusing to replace unexpected path: $TARGET" >&2
    exit 1
fi
rm -rf "$TARGET"
/usr/bin/ditto "$APP" "$TARGET"
echo "Created $TARGET"
```

- [ ] **Step 6: Update ignored generated files**

Replace `.gitignore` with:

```gitignore
.build/
.DS_Store
.swiftpm/
.worktrees/
dist/
*.xcuserstate
```

Remove the already tracked root `.DS_Store` from Git:

```bash
git rm --cached .DS_Store
```

- [ ] **Step 7: Run packaging verification**

Run:

```bash
bash -n scripts/generate-icon.sh scripts/package-app.sh Tests/PackagingChecks.sh
bash Tests/PackagingChecks.sh
```

Expected: shell syntax succeeds and `Packaging checks passed`.

- [ ] **Step 8: Commit Task 1**

```bash
git add VERSION Resources scripts/generate-icon.sh scripts/package-app.sh \
  Tests/PackagingChecks.sh .gitignore Package.swift .DS_Store
git commit -m "build: package native macOS app"
```

---

### Task 2: Safe Install, Update, and Uninstall

**Files:**
- Create: `setup.sh`
- Create: `scripts/uninstall.sh`
- Create: `Tests/InstallerChecks.sh`
- Modify: `README.md` only if Task 4 has already created it; otherwise defer documentation to Task 4

**Interfaces:**
- Consumes: `scripts/package-app.sh [--output-dir PATH]`
- Produces: `setup.sh [--skip-tests] [--no-launch] [--install-dir PATH]`
- Produces: `scripts/uninstall.sh [--purge-data] [--install-dir PATH]`
- Default installation: `~/Applications/Echofloat.app`

- [ ] **Step 1: Write the failing installer lifecycle check**

Create `Tests/InstallerChecks.sh`:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR%/}/echofloat-installer-tests.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

"$ROOT/setup.sh" --skip-tests --no-launch --install-dir "$TMP_ROOT/Applications"
APP="$TMP_ROOT/Applications/Echofloat.app"
test -x "$APP/Contents/MacOS/echofloat"
/usr/bin/codesign --verify --deep --strict "$APP"

"$ROOT/scripts/uninstall.sh" --install-dir "$TMP_ROOT/Applications"
test ! -e "$APP"

echo "Installer checks passed"
```

- [ ] **Step 2: Run the lifecycle check to verify it fails**

Run:

```bash
bash Tests/InstallerChecks.sh
```

Expected: FAIL because `setup.sh` does not exist.

- [ ] **Step 3: Implement the one-command installer**

Create `setup.sh` with argument parsing for `--skip-tests`, `--no-launch`, and `--install-dir PATH`.

Required behavior:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/Applications"
RUN_TESTS=true
LAUNCH=true
```

After parsing:

```bash
if $RUN_TESTS; then
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=safe.bareRepository \
    GIT_CONFIG_VALUE_0=all \
        swift test
fi

"$ROOT/scripts/package-app.sh"
mkdir -p "$INSTALL_DIR"

TARGET="$INSTALL_DIR/Echofloat.app"
STAGING="$INSTALL_DIR/.Echofloat.installing.$$"
BACKUP="$INSTALL_DIR/.Echofloat.backup.$$"
trap 'rm -rf "$STAGING"; if [[ -d "$BACKUP" && ! -e "$TARGET" ]]; then mv "$BACKUP" "$TARGET"; fi' EXIT

/usr/bin/ditto "$ROOT/dist/Echofloat.app" "$STAGING"
/usr/bin/codesign --verify --deep --strict "$STAGING"

if [[ -d "$TARGET" ]]; then
    mv "$TARGET" "$BACKUP"
fi
mv "$STAGING" "$TARGET"
rm -rf "$BACKUP"
trap - EXIT

if $LAUNCH; then
    /usr/bin/open "$TARGET"
fi
```

Before replacing the app, request graceful termination only for bundle identifier `com.echofloat.app`:

```bash
/usr/bin/osascript -e 'tell application id "com.echofloat.app" to quit' \
    >/dev/null 2>&1 || true
```

Print:

```text
Echofloat installed at ~/Applications/Echofloat.app

For YouTube Music:
1. In Chrome, enable View > Developer > Allow JavaScript from Apple Events.
2. When macOS asks, allow Echofloat to automate Google Chrome.
```

- [ ] **Step 4: Implement safe uninstall**

Create `scripts/uninstall.sh`. Parse `--purge-data` and `--install-dir PATH`. Remove only:

- `$INSTALL_DIR/Echofloat.app`
- `~/Library/LaunchAgents/com.echofloat.autostart.plist`
- With `--purge-data` only:
  - `~/Library/Application Support/Echofloat`
  - Echofloat defaults domain `com.echofloat.app`

Before removal:

```bash
/usr/bin/osascript -e 'tell application id "com.echofloat.app" to quit' \
    >/dev/null 2>&1 || true
```

Reject unknown flags and refuse cleanup when `INSTALL_DIR` is empty or `/`.

- [ ] **Step 5: Run installer lifecycle verification**

Run:

```bash
chmod +x setup.sh scripts/uninstall.sh Tests/InstallerChecks.sh
bash -n setup.sh scripts/uninstall.sh Tests/InstallerChecks.sh
bash Tests/InstallerChecks.sh
```

Expected: shell syntax succeeds and `Installer checks passed`.

- [ ] **Step 6: Commit Task 2**

```bash
git add setup.sh scripts/uninstall.sh Tests/InstallerChecks.sh
git commit -m "feat: add one-command local install"
```

---

### Task 3: Modern Launch at Login

**Files:**
- Create: `Sources/echofloat/Support/LoginItemService.swift`
- Modify: `Sources/echofloat/Support/AutostartManager.swift`
- Modify: `Sources/echofloat/MenuBar/StatusItemController.swift`
- Modify: `Sources/echofloat/App/AppDelegate.swift`
- Replace: `Tests/echofloatTests/AutostartManagerTests.swift`

**Interfaces:**
- Produces: `enum LoginItemStatus { case notRegistered, enabled, requiresApproval, notFound }`
- Produces: `protocol LoginItemServicing`
- Produces: `struct MainAppLoginItemService: LoginItemServicing`
- Produces: `AutostartManager.status: LoginItemStatus`
- Produces: `AutostartManager.setEnabled(_ enabled: Bool) throws`
- Produces: `AutostartManager.removeLegacyLaunchAgent() throws`

- [ ] **Step 1: Replace legacy-file tests with failing service tests**

Replace `Tests/echofloatTests/AutostartManagerTests.swift`:

```swift
import Foundation
import Testing
@testable import echofloat

private enum FakeError: Error {
    case register
    case unregister
}

private final class FakeLoginItemService: LoginItemServicing {
    var status: LoginItemStatus = .notRegistered
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

@Test func reflectsServiceStatus() {
    let service = FakeLoginItemService()
    service.status = .requiresApproval
    let manager = AutostartManager(service: service)
    #expect(manager.status == .requiresApproval)
    #expect(manager.isEnabled == false)
}

@Test func enablingRegistersMainApp() throws {
    let service = FakeLoginItemService()
    let manager = AutostartManager(service: service)
    try manager.setEnabled(true)
    #expect(service.registerCalls == 1)
    #expect(manager.isEnabled)
}

@Test func disablingUnregistersMainApp() throws {
    let service = FakeLoginItemService()
    service.status = .enabled
    let manager = AutostartManager(service: service)
    try manager.setEnabled(false)
    #expect(service.unregisterCalls == 1)
    #expect(manager.isEnabled == false)
}

@Test func registrationErrorsPropagate() {
    let service = FakeLoginItemService()
    service.registerError = FakeError.register
    let manager = AutostartManager(service: service)
    #expect(throws: FakeError.self) {
        try manager.setEnabled(true)
    }
}

@Test func removesLegacyLaunchAgent() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let plist = directory.appendingPathComponent("com.echofloat.autostart.plist")
    try "legacy".write(to: plist, atomically: true, encoding: .utf8)
    let manager = AutostartManager(
        service: FakeLoginItemService(),
        legacyLaunchAgentsDirectory: directory
    )
    try manager.removeLegacyLaunchAgent()
    #expect(FileManager.default.fileExists(atPath: plist.path) == false)
}
```

- [ ] **Step 2: Run focused tests to verify they fail**

Run:

```bash
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.bareRepository \
GIT_CONFIG_VALUE_0=all \
swift test --filter AutostartManager
```

Expected: FAIL because `LoginItemServicing` and the new manager API do not exist.

- [ ] **Step 3: Implement the ServiceManagement boundary**

Create `Sources/echofloat/Support/LoginItemService.swift`:

```swift
import ServiceManagement

enum LoginItemStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

protocol LoginItemServicing: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

final class MainAppLoginItemService: LoginItemServicing {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LoginItemStatus {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
```

- [ ] **Step 4: Replace the LaunchAgent writer**

Implement `AutostartManager` around `LoginItemServicing`:

```swift
import Foundation

final class AutostartManager {
    private let service: LoginItemServicing
    private let fileManager: FileManager
    private let legacyPlistURL: URL

    init(
        service: LoginItemServicing = MainAppLoginItemService(),
        legacyLaunchAgentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents"),
        fileManager: FileManager = .default
    ) {
        self.service = service
        self.fileManager = fileManager
        legacyPlistURL = legacyLaunchAgentsDirectory
            .appendingPathComponent("com.echofloat.autostart.plist")
    }

    var status: LoginItemStatus { service.status }
    var isEnabled: Bool { status == .enabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    func removeLegacyLaunchAgent() throws {
        guard fileManager.fileExists(atPath: legacyPlistURL.path) else { return }
        try fileManager.removeItem(at: legacyPlistURL)
    }
}
```

- [ ] **Step 5: Surface registration failures in the menu**

Change `StatusItemController.toggleAutostart()`:

```swift
@objc private func toggleAutostart() {
    do {
        try autostartManager.setEnabled(!autostartManager.isEnabled)
    } catch {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t update Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSLog("Echofloat: Launch at Login failed: \(error.localizedDescription)")
    }
    buildMenu()
}
```

When `status == .requiresApproval`, title the menu item `Launch at Login (Approval Required)` and leave it unchecked. Other states use `Launch at Login`.

In `AppDelegate.applicationDidFinishLaunching`, remove legacy state explicitly:

```swift
let autostartManager = AutostartManager()
do {
    try autostartManager.removeLegacyLaunchAgent()
} catch {
    NSLog("Echofloat: Could not remove legacy login item: \(error.localizedDescription)")
}
```

- [ ] **Step 6: Run focused and full Swift tests**

Run:

```bash
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.bareRepository \
GIT_CONFIG_VALUE_0=all \
swift test --filter AutostartManager

GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.bareRepository \
GIT_CONFIG_VALUE_0=all \
swift test
```

Expected: all AutostartManager tests and the complete suite pass.

- [ ] **Step 7: Commit Task 3**

```bash
git add Sources/echofloat/Support/LoginItemService.swift \
  Sources/echofloat/Support/AutostartManager.swift \
  Sources/echofloat/MenuBar/StatusItemController.swift \
  Sources/echofloat/App/AppDelegate.swift \
  Tests/echofloatTests/AutostartManagerTests.swift
git commit -m "feat: use native launch at login"
```

---

### Task 4: Public Documentation and License

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `CONTRIBUTING.md`

**Interfaces:**
- Documents: `./setup.sh`
- Documents: `./scripts/uninstall.sh [--purge-data]`
- Documents: Chrome Apple Events permission and macOS Automation permission

- [ ] **Step 1: Add the MIT license**

Create `LICENSE` with the standard MIT license text, copyright year `2026`, and copyright holder `Echofloat contributors`.

- [ ] **Step 2: Write the public README**

Create `README.md` with these exact top-level sections:

```markdown
# Echofloat

Animated, always-visible lyrics and playback controls for macOS.

## Features
## Requirements
## Install
## First-run setup
## Use Echofloat
## Update
## Uninstall
## Supported players
## Privacy
## Troubleshooting
## Development
## Architecture
## Limitations and roadmap
## Contributing
## License
```

Required install command:

```bash
git clone https://github.com/d-stash/echofloat.git
cd echofloat
./setup.sh
```

Required compatibility table:

| Player | Metadata and lyrics | Controls | Extra setup |
|---|---:|---:|---|
| YouTube Music in Chrome | Yes | Yes | Chrome JavaScript from Apple Events + macOS Automation |
| Apple Music | Yes | Yes | macOS Automation approval when prompted |
| Spotify | Yes | Yes | macOS Automation approval when prompted |

State clearly:

- Echofloat requires macOS 13+.
- The source installer builds natively with Apple Command Line Tools.
- The current project does not ship a notarized downloadable binary.
- Lyrics come from LRCLIB and may be missing or unsynchronized.
- No account, browser session token, analytics, or telemetry is used.
- Cached lyrics live under `~/Library/Application Support/Echofloat/LyricsCache`.

Required troubleshooting commands:

```bash
tccutil reset AppleEvents com.echofloat.app
./setup.sh
./scripts/uninstall.sh
./scripts/uninstall.sh --purge-data
```

Do not add badges that point to workflows or releases until those endpoints exist.

- [ ] **Step 3: Add contribution guidance**

Create `CONTRIBUTING.md` covering:

- macOS 13+ and Swift 5.9+ prerequisites
- `swift test`
- `swift build`
- `bash Tests/PackagingChecks.sh`
- `bash Tests/InstallerChecks.sh`
- coding expectations: focused changes, tests for behavior, no private Apple frameworks, no committed secrets or borrowed artwork
- pull-request checklist for tests, docs, privacy/permission changes, and screenshots

- [ ] **Step 4: Validate documentation against scripts**

Run:

```bash
grep -F './setup.sh' README.md
grep -F './scripts/uninstall.sh' README.md
grep -F 'tccutil reset AppleEvents com.echofloat.app' README.md
grep -F 'swift test' CONTRIBUTING.md
test -s LICENSE
```

Expected: all commands exit successfully.

- [ ] **Step 5: Commit Task 4**

```bash
git add README.md LICENSE CONTRIBUTING.md
git commit -m "docs: add public setup guide"
```

---

### Task 5: Continuous Integration and End-to-End Validation

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `Tests/PackagingChecks.sh`
- Modify: `Tests/InstallerChecks.sh`

**Interfaces:**
- Consumes: all test and packaging commands from Tasks 1–4
- Produces: GitHub Actions `CI` workflow for pushes and pull requests

- [ ] **Step 1: Add the macOS CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify:
    runs-on: macos-15
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Validate shell scripts
        run: bash -n setup.sh scripts/*.sh Tests/*.sh
      - name: Run Swift tests
        run: swift test
      - name: Run animation checks
        run: |
          swiftc Sources/echofloat/Theming/Theme.swift \
            Sources/echofloat/Theming/ThemeAnimation.swift \
            Tests/ThemeAnimationChecks.swift \
            -o "$RUNNER_TEMP/theme-checks"
          "$RUNNER_TEMP/theme-checks"
      - name: Run playback timing checks
        run: |
          swiftc Sources/echofloat/Models/TrackSignature.swift \
            Sources/echofloat/Models/NowPlayingState.swift \
            Sources/echofloat/Playback/PlaybackClock.swift \
            Tests/PlaybackTimingChecks.swift \
            -o "$RUNNER_TEMP/playback-checks"
          "$RUNNER_TEMP/playback-checks"
      - name: Verify app packaging
        run: bash Tests/PackagingChecks.sh
      - name: Verify installer lifecycle
        run: bash Tests/InstallerChecks.sh
```

- [ ] **Step 2: Run every CI command locally**

Run:

```bash
bash -n setup.sh scripts/*.sh Tests/*.sh

GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.bareRepository \
GIT_CONFIG_VALUE_0=all \
swift test

swiftc Sources/echofloat/Theming/Theme.swift \
  Sources/echofloat/Theming/ThemeAnimation.swift \
  Tests/ThemeAnimationChecks.swift \
  -o /tmp/echofloat-theme-checks
/tmp/echofloat-theme-checks

swiftc Sources/echofloat/Models/TrackSignature.swift \
  Sources/echofloat/Models/NowPlayingState.swift \
  Sources/echofloat/Playback/PlaybackClock.swift \
  Tests/PlaybackTimingChecks.swift \
  -o /tmp/echofloat-playback-checks
/tmp/echofloat-playback-checks

bash Tests/PackagingChecks.sh
bash Tests/InstallerChecks.sh
```

Expected: every command exits zero.

- [ ] **Step 3: Verify installed app behavior**

Run:

```bash
./setup.sh --no-launch
/usr/bin/plutil -lint "$HOME/Applications/Echofloat.app/Contents/Info.plist"
/usr/bin/codesign --verify --deep --strict "$HOME/Applications/Echofloat.app"
/usr/bin/open "$HOME/Applications/Echofloat.app"
sleep 2
pgrep -f "$HOME/Applications/Echofloat.app/Contents/MacOS/echofloat"
```

Expected: one PID is returned. If a prior development instance exists, stop its exact PID before launching the installed app.

- [ ] **Step 4: Verify Launch at Login manually**

From the Echofloat menu:

1. Enable **Launch at Login**.
2. Open **System Settings > General > Login Items**.
3. Confirm Echofloat appears and is enabled.
4. Disable **Launch at Login**.
5. Confirm the menu and System Settings both report it disabled.

If macOS reports approval is required, approve Echofloat in Login Items and repeat the check. Do not leave Launch at Login enabled unless it was enabled before this verification.

- [ ] **Step 5: Inspect public diff and generated-artifact boundaries**

Run:

```bash
git status --short
git diff --check
git ls-files dist .build .DS_Store
```

Expected:

- Only intended source, scripts, resources, docs, tests, workflow, and package metadata are tracked.
- `git diff --check` emits no errors.
- `git ls-files dist .build .DS_Store` emits no paths.

- [ ] **Step 6: Commit Task 5**

```bash
git add .github/workflows/ci.yml Tests/PackagingChecks.sh Tests/InstallerChecks.sh
git commit -m "ci: verify public app packaging"
```

- [ ] **Step 7: Update tracked task status**

Mark `app-bundle-packaging` done after Tasks 1–5 pass. Mark `autostart-verify` done only after the manual System Settings status check succeeds.
