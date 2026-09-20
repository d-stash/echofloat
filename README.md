# Echofloat

Animated, always-visible lyrics and playback controls for macOS.

## Features

- Live lyrics from LRCLIB with local caching for repeat playback.
- Playback control support for YouTube Music in Chrome, Apple Music, and Spotify.
- A menu bar app with theme controls, visibility controls, and Launch at Login.
- A lightweight local build that installs into `~/Applications/Echofloat.app`.

## Run locally

Prerequisites:

- macOS 13 or later
- Git
- Apple Command Line Tools with Swift 5.9 or newer

Install the Command Line Tools if needed:

```bash
xcode-select --install
```

Then clone, build, install, and launch Echofloat:

```bash
git clone https://github.com/d-stash/echofloat.git
cd echofloat
./setup.sh
```

The app is installed at `~/Applications/Echofloat.app`. To run a development build without installing the app:

```bash
swift run echofloat
```

Google Chrome is only required for YouTube Music. macOS will request Automation access when Echofloat first controls Chrome, Music, or Spotify.

## First-run setup

On first launch, macOS may ask for Automation approval. Approve access for Echofloat to control the music app you use.

For YouTube Music in Chrome, enable Apple Events JavaScript in Chrome:

1. Open Chrome.
2. Go to View > Developer.
3. Turn on Allow JavaScript from Apple Events.
4. Approve the macOS Automation prompt for Echofloat -> Google Chrome.

## Use Echofloat

Use the menu bar icon to show or hide the overlay, switch themes, toggle display mode, and control Launch at Login.

Playback controls and lyrics track the active supported player automatically.

## Update

Run the installer again:

```bash
./setup.sh
```

## Uninstall

Remove the app and legacy login item:

```bash
./scripts/uninstall.sh
```

This preserves local data by default.

To also remove local cache and defaults:

```bash
./scripts/uninstall.sh --purge-data
```

## Supported players

| Player | Metadata and lyrics | Controls | Extra setup |
|---|---:|---:|---|
| YouTube Music in Chrome | Yes | Yes | Chrome JavaScript from Apple Events + macOS Automation |
| Apple Music | Yes | Yes | macOS Automation approval when prompted |
| Spotify | Yes | Yes | macOS Automation approval when prompted |

## Privacy

Echofloat does not use an account, browser session token, analytics, or telemetry.

Lyrics requests go to LRCLIB. Results may be missing or unsynchronized, and cached lyrics are stored locally at `~/Library/Application Support/Echofloat/LyricsCache`.

## Troubleshooting

If Chrome automation stops working, reset the Apple Events permission and rerun setup:

```bash
tccutil reset AppleEvents com.echofloat.app
./setup.sh
```

If Launch at Login shows an approval state, open **System Settings > General > Login Items** and enable Echofloat. The menu may show `Launch at Login (Approval Required)` until approval is complete.

## Development

Build and test from the repository root:

```bash
swift build
bash Tests/PackagingChecks.sh
bash Tests/InstallerChecks.sh
```

The app builds with Swift 5.9 or newer. The full Swift Testing suite requires Swift 6.1 or newer:

```bash
swift test --no-parallel
```

The source build is ad-hoc signed locally. This project does not ship a notarized downloadable binary.

## Architecture

Echofloat uses a Swift 5.9 base package for the app and a version-specific Swift 6.1 package manifest for the full test suite.

- `Sources/echofloat/App` wires the app together.
- `Sources/echofloat/MediaSources` reads now-playing state from Apple Music, Spotify, and Chrome-based YouTube Music.
- `Sources/echofloat/Lyrics` fetches and caches lyrics.
- `Sources/echofloat/MenuBar` and `Sources/echofloat/Overlay` drive the menu bar UI and floating lyrics panel.
- `Sources/echofloat/Support` manages Launch at Login through `SMAppService.mainApp` and related app lifecycle behavior.

## Limitations and roadmap

- YouTube Music support depends on Chrome automation permissions and can be blocked until Apple Events access is approved.
- Lyrics quality depends on LRCLIB coverage and timing.
- The current release is source-built locally; there is no downloadable notarized binary.
- Future work may expand player coverage and polish the overlay, but no roadmap items are committed in this repository.

## Contributing

See `CONTRIBUTING.md` for local development, testing, and pull-request guidance.

## License

Echofloat is available under the MIT License. See `LICENSE`.
