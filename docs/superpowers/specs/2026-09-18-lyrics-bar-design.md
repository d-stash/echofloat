# LyricsBar — Design Spec

Status: **Draft, awaiting owner review.** The user was unavailable mid-session,
so every decision below was made autonomously with the best available
information. Items marked **(ASSUMPTION)** are the ones most likely to change
once you review — read those first.

## 1. Summary

A native macOS menu-bar + "dynamic island" style app that shows a
transparent, liquid-glass overlay near the notch/menu bar, always displaying
synced lyrics for whatever is currently playing, with playback controls, on
one or all connected displays. Themeable (starts with 2 themes, easy to add
more). v1 music source: YouTube Music. Architecture designed so more sources
(Spotify, Apple Music, etc.) can be added later without touching existing
code.

Reference/precedent in this workspace: `../top-notch` — a dependency-free
Swift/AppKit/SwiftUI menu-bar notch app. LyricsBar reuses its proven
techniques (notch geometry anchoring, click-through `NSPanel`, status item,
launchd autostart) but is a **new, separate project**, not a fork.

## 2. Integration approach for "connecting to your account" **(ASSUMPTION — biggest deviation from the original ask)**

You described wanting to connect "using session token or anything of some
sort." I researched the realistic options:

| Option | Reads track info | Controls playback | Setup required | Lyrics available |
|---|---|---|---|---|
| **System MediaRemote / Now Playing** (private Apple framework used by Control Center) | Yes — any app/tab that plays media and sets the Media Session API (YouTube Music web player does this) | Yes (play/pause/next/prev, system-wide) | **None** — works the moment YT Music plays in a Safari/Chrome tab or as a PWA | Not included; must fetch from a 3rd party |
| YouTube Music Desktop App (`ytmdesktop`) Companion Server REST/WebSocket | Yes, richer metadata | Yes | User must install & run the separate Electron `ytmdesktop` app, then pair a token | Same problem — no native lyrics either |
| Official YouTube Data API | No now-playing/session concept | No playback control at all | OAuth app registration | N/A |

**Decision:** v1 uses **MediaRemote** (same technique as the open-source
`nowplaying-cli` tool). Zero setup, matches the "just works" feel of
`top-notch`. No session token/login screen is needed for v1 — this is a
deliberate scope cut versus the original idea, please confirm you're OK with
it. If you'd rather require the `ytmdesktop` companion API for tighter
control, that's a straightforward alternate `MusicSource` implementation we
can add later (see §4).

**Known limitation:** MediaRemote reports whichever app/tab last became the
system's "Now Playing" session — it's not exclusively scoped to YouTube
Music. The UI will show the source app name so it's obvious what's being
tracked; if something else briefly grabs focus (e.g., a YouTube video in
another tab), the overlay will reflect that instead until YT Music resumes.

## 3. Lyrics source

YouTube Music has no public lyrics API. v1 uses **LRCLIB**
(`https://lrclib.net/api/get`), a free, keyless, synced-lyrics API queried by
artist/title/duration. Falls back to unsynced plain lyrics if no synced
match, and to "no lyrics found" if neither exists. Results are cached
in-memory + on disk keyed by track signature to avoid refetching on repeat
plays.

## 4. Architecture

Multi-file Swift package (unlike `top-notch`'s single 2,453-line file — split
here for maintainability since this app has more moving parts):

```
Sources/lyricsbar/
  App/            AppDelegate, entry point
  MediaSources/   MusicSource protocol + SystemNowPlayingSource (MediaRemote wrapper)
  Lyrics/         LyricsProvider protocol + LRCLibProvider, LyricLine model, on-disk cache
  Overlay/        Per-screen NSPanel controller, NotchGeometry, LiquidGlassBackground,
                  CollapsedPillView, ExpandedLyricsPanelView
  Theming/        Theme model + built-in theme registry, ThemeManager
  MenuBar/        NSStatusItem controller (show/hide, display mode, theme picker, autostart, quit)
  Support/        UserDefaults keys, launchd autostart helper (reused pattern from top-notch)
```

Two protocols make the "support multiple apps in the future" requirement
concrete instead of aspirational:

```swift
protocol MusicSource {
    var nowPlaying: AsyncStream<NowPlayingState> { get }
    func play(); func pause(); func next(); func previous()
}

protocol LyricsProvider {
    func lyrics(for track: TrackSignature) async -> LyricsResult
}
```

v1 ships one implementation of each (`SystemNowPlayingSource`,
`LRCLibProvider`). Adding Spotify/Apple Music/`ytmdesktop` later means adding
a new `MusicSource` conformance — no changes to overlay, theming, or menu bar
code.

## 5. Overlay UI (the "dynamic island" feel)

- Borderless, transparent, floating `NSPanel`, one per connected display —
  **(ASSUMPTION)** overlay mirrors on **all displays** by default, with a
  menu-bar toggle for "Active Display Only," since you said "work on both
  screens."
- Anchored top-center near the physical notch (reusing `top-notch`'s
  `NotchGeometry` approach), graceful fallback position on notchless/external
  displays.
- **Collapsed state:** small pill, click-through (`ignoresMouseEvents`) so it
  never blocks clicks on whatever's behind it — shows a mini waveform +
  truncated current lyric line.
- **Expanded state** (on hover/click): larger glass panel, interactive,
  scrolling synced lyrics with the current line highlighted, playback
  controls (prev/play-pause/next), source app name.
- Visual style: SwiftUI `.ultraThinMaterial` + soft animated glow layer for
  the "liquid glass" look; fully see-through background content remains
  visible/controllable behind it.

## 6. Theming

`Theme` struct: id, name, background gradient, accent color, glass blur
intensity, optional motif (e.g., particle/grid overlay), font. Built-in
registry ships 2 launch themes:

1. **Aurora Glass** (default) — clean, neutral, minimal glass, closest to
   `top-notch`'s look.
2. **Neon Arcade** — gaming/anime-adjacent: dark background, neon
   magenta/cyan accents, subtle animated grid motif.

Adding a theme later = appending one struct literal to the registry (plus an
optional motif view) — no other code changes, satisfying "keep options to
easily add more."

## 7. Menu bar & persistence

`NSStatusItem` dropdown: show/hide overlay, display mode (all vs. active),
theme picker, "Launch at Login" (reusing `top-notch`'s launchd script
pattern), quit. All preferences persist via `UserDefaults` — no Keychain
prompts, matching `top-notch`'s zero-friction convention.

## 8. Explicit scope cuts for v1 (revisit later)

- No login/session-token screen (see §2's rationale).
- No `ytmdesktop` companion API integration yet — placeholder architecture
  only.
- No Spotify/Apple Music sources yet — architecture supports them, not built.
- Only 2 themes.
- macOS only (matches `top-notch`; no cross-platform ask was made).

## 9. Tech stack

Swift 5.9+, SwiftUI + AppKit, Swift Package Manager executable target,
macOS 13+ (Ventura), zero third-party dependencies (matches `top-notch`'s
"native only" philosophy) — the only network calls are to LRCLIB's public
HTTP API.
