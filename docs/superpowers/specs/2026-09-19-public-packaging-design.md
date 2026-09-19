# Echofloat Public Packaging Design

**Date:** 2026-09-19

## Goal

Make Echofloat straightforward to clone, build, install, use, update, and remove on macOS while keeping the repository lightweight and honest about unsigned public distribution.

The primary supported path is source installation:

```bash
git clone https://github.com/d-stash/echofloat.git
cd echofloat
./setup.sh
```

This release does not publish a downloadable prebuilt app. A broadly distributed binary would require an Apple Developer ID certificate and notarization for a seamless Gatekeeper experience.

## Supported Environment

- macOS 13 Ventura or newer
- Apple Silicon or Intel Mac, built natively on the user's machine
- Apple Command Line Tools with Swift 6.1 or newer
- Google Chrome for YouTube Music integration
- Optional Apple Music or Spotify playback

Full Xcode and third-party project generators are not required.

## Packaging Architecture

The Swift package remains the source of truth. Packaging uses repository-owned shell scripts and standard macOS tools:

- `setup.sh` is the user-facing installer.
- `scripts/package-app.sh` builds and assembles an app bundle.
- `scripts/uninstall.sh` removes the installed app and its login-item registration.
- `Resources/Info.plist` defines stable bundle metadata and privacy usage text.
- `Resources/AppIcon.icns` supplies the Finder and application icon.
- `dist/Echofloat.app` is generated output and is ignored by Git.

`scripts/package-app.sh` will:

1. Validate that it is running on supported macOS and that `swift`, `plutil`, and `codesign` are available.
2. Run a release SwiftPM build for the current architecture.
3. Create the conventional `Echofloat.app/Contents/{MacOS,Resources}` structure.
4. Copy the executable, `Info.plist`, and icon into the bundle.
5. Apply an ad-hoc signature to the locally built app.
6. Validate the property list, bundle structure, executable architecture, and signature.

`setup.sh` will:

1. Run the test suite before installation.
2. Call the packaging script.
3. Install atomically to `~/Applications/Echofloat.app` without requiring `sudo`.
4. Replace only a prior Echofloat installation at that exact path.
5. Launch the installed app with `open`.
6. Print the two one-time Chrome/Automation permission steps.

Re-running `setup.sh` is the supported update flow. It preserves preferences and lyrics cache under the user's Library.

## Bundle Metadata and Permissions

The app bundle uses a stable reverse-DNS identifier, `com.echofloat.app`, and includes:

- `CFBundleDisplayName`: `Echofloat`
- `CFBundleExecutable`: `echofloat`
- `CFBundlePackageType`: `APPL`
- `CFBundleShortVersionString` and `CFBundleVersion`
- `LSMinimumSystemVersion`: `13.0`
- `LSUIElement`: `true`
- `NSAppleEventsUsageDescription`: a plain explanation that Echofloat reads and controls the active supported music player to display synchronized lyrics

The local build is ad-hoc signed. The scripts do not bypass Gatekeeper, clear quarantine attributes, modify system security settings, request administrator access, or write global Git configuration.

## Launch at Login

The existing hand-written LaunchAgent implementation will be replaced with `SMAppService.mainApp`, available on the minimum supported macOS version.

`AutostartManager` will expose an injectable service boundary so registration behavior remains unit-testable. Enabling and disabling will call the operating-system service directly. Failures will be logged and returned to the menu controller rather than hidden.

The menu item will reflect the service's actual status. If registration fails, Echofloat will show a user-visible alert with a concise recovery path to System Settings.

Legacy `~/Library/LaunchAgents/com.echofloat.autostart.plist` files created by older development builds will be removed during migration and uninstall.

## Integrations and Privacy

Echofloat does not require an Echofloat account and does not collect or store browser session tokens.

- YouTube Music is read and controlled through Google Chrome Apple Events and in-page JavaScript.
- Apple Music and Spotify are observed through their public distributed playback notifications, with AppleScript used for controls and position correction.
- Lyrics are requested from the public LRCLIB API and cached locally under `~/Library/Application Support/Echofloat/LyricsCache`.
- Theme, overlay, and display preferences remain local through `UserDefaults`.

The README will document:

1. Enabling Chrome's **View > Developer > Allow JavaScript from Apple Events** option.
2. Approving **System Settings > Privacy & Security > Automation > Echofloat > Google Chrome**.
3. What network and inter-application access the app uses.
4. How to reset Automation permission if permission was denied.

## Public Repository Experience

The repository will include:

- `README.md`: overview, feature list, compatibility matrix, install/update/uninstall, first-run permissions, usage, troubleshooting, development, architecture, privacy, limitations, and roadmap
- `LICENSE`: MIT license
- `CONTRIBUTING.md`: focused development and pull-request guidance
- `.github/workflows/ci.yml`: macOS build, tests, standalone checks, package validation, and shell syntax validation
- Improved `.gitignore`: generated bundles, distribution output, Swift build products, and macOS metadata
- Swift package metadata suitable for public tooling

README visuals will use repository-owned screenshots only. Placeholder links or borrowed product artwork will not be committed.

## Verification

Automated verification will cover:

- Existing Swift Testing suite
- Playback and animation standalone checks
- Autostart status, registration, unregistration, and error propagation through a test service
- Valid `Info.plist` keys and values
- Expected `.app` directory structure
- Executable presence and permissions
- Successful ad-hoc signature verification
- Shell syntax for all scripts

The final local validation sequence is:

1. Run all tests.
2. Build the release executable.
3. Package and validate `dist/Echofloat.app`.
4. Install to `~/Applications/Echofloat.app`.
5. Verify exactly one installed Echofloat process launches.
6. Exercise Launch at Login registration and verify the operating-system status.
7. Disable Launch at Login after verification unless it was already enabled.

## Out of Scope

- Developer ID signing and Apple notarization
- Mac App Store packaging
- Homebrew cask publication
- Automatic updates
- Crash analytics or telemetry
- New media providers
- Theme redesigns

The packaging scripts will be structured so a future notarized release workflow can reuse the generated bundle without changing application architecture.
