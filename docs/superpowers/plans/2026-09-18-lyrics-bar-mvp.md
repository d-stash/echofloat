# LyricsBar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app that overlays a transparent
"liquid glass" pill near the notch, shows synced lyrics for whatever is
currently playing (YouTube Music, Spotify, Apple Music, or any browser tab),
lets the user control playback, and supports switching between 2 built-in
themes.

**Architecture:** Swift Package Manager executable target using
SwiftUI + AppKit only (no third-party dependencies). System playback state
comes from the private `MediaRemote` framework via a small protocol-based
bridge (`MediaRemoteClient`) so business logic stays testable without the
real framework. Lyrics come from the free LRCLIB HTTP API, cached to disk.
`PlayerViewModel` ties a `MusicSource` + `LyricsProvider` + `LyricsCache`
together and drives one `NSPanel` overlay per screen plus a menu-bar status
item.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Swift Testing (`import Testing`,
bundled with Swift 5.9+ toolchains) for unit tests, `Foundation.URLSession`
for networking. Zero external package dependencies.

**Spec:** `docs/superpowers/specs/2026-09-18-lyrics-bar-design.md`

## Global Constraints

- Platform floor: macOS 13.0 (Ventura), Swift tools version 5.9.
- Zero third-party dependencies — everything ships via Apple's SDKs only.
- No Keychain access, no OAuth/login screen — preferences persist via
  `UserDefaults` only (matches `top-notch`'s zero-friction convention).
- Lyrics come only from `https://lrclib.net/api/get` (no API key) — no other
  lyrics provider in v1.
- Exactly 2 built-in themes at launch: `Aurora Glass` (default) and
  `Neon Arcade`. New themes must be addable by appending one entry to
  `Theme.builtIn` — no other file should need to change to add a 3rd theme.
- Every file has one clear responsibility; keep files small (this plan
  intentionally splits ~12 single-purpose files instead of one large file,
  unlike `top-notch`'s monolith).

---

## File Structure

```
lyrics-bar/
  Package.swift
  Sources/lyricsbar/
    App/
      main.swift
      AppDelegate.swift
    Models/
      TrackSignature.swift
      NowPlayingState.swift
      LyricLine.swift
      LyricsResult.swift
    Lyrics/
      LyricsProvider.swift
      LRCParser.swift
      LRCLibProvider.swift
      LyricsCache.swift
    MediaSources/
      MusicSource.swift
      MediaRemoteClient.swift
      SystemNowPlayingSource.swift
    Theming/
      Theme.swift
      ThemeManager.swift
    ViewModel/
      PlayerViewModel.swift
    Overlay/
      ScreenMetrics.swift
      NotchGeometry.swift
      ColorHex.swift
      VisualEffectBlur.swift
      NeonGridMotif.swift
      LiquidGlassBackground.swift
      CollapsedPillView.swift
      ExpandedLyricsPanelView.swift
      OverlayWindowController.swift
    MenuBar/
      StatusItemController.swift
    Support/
      AutostartManager.swift
  Tests/lyricsbarTests/
    TrackSignatureTests.swift
    LRCParserTests.swift
    LRCLibProviderTests.swift
    LyricsCacheTests.swift
    SystemNowPlayingSourceTests.swift
    ThemeManagerTests.swift
    PlayerViewModelTests.swift
    NotchGeometryTests.swift
    AutostartManagerTests.swift
```

---

### Task 1: Project scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/lyricsbar/App/main.swift`
- Create: `Sources/lyricsbar/App/AppDelegate.swift`
- Test: none (no testable logic yet — verified by running the app)

**Interfaces:**
- Produces: an `AppDelegate` class and a running SPM executable target
  named `lyricsbar`, plus a `lyricsbarTests` test target that later tasks
  add test files to.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lyricsbar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "lyricsbar"),
        .testTarget(name: "lyricsbarTests", dependencies: ["lyricsbar"]),
    ]
)
```

- [ ] **Step 2: Write a minimal `AppDelegate`**

```swift
// Sources/lyricsbar/App/AppDelegate.swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "LyricsBar")
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit LyricsBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

- [ ] **Step 3: Write the entry point**

```swift
// Sources/lyricsbar/App/main.swift
import AppKit

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
```

- [ ] **Step 4: Build and smoke-test**

Run: `swift build`
Expected: builds with no errors.

Run: `swift run &` then check the menu bar for a music-note icon; click it,
confirm "Quit LyricsBar" appears and quits the app. Then run
`kill %1` if the background job is still around.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/lyricsbar/App
git commit -m "feat: scaffold lyricsbar SPM executable with menu bar stub"
```

---

### Task 2: Core models

**Files:**
- Create: `Sources/lyricsbar/Models/TrackSignature.swift`
- Create: `Sources/lyricsbar/Models/NowPlayingState.swift`
- Create: `Sources/lyricsbar/Models/LyricLine.swift`
- Create: `Sources/lyricsbar/Models/LyricsResult.swift`
- Test: `Tests/lyricsbarTests/TrackSignatureTests.swift`

**Interfaces:**
- Produces: `TrackSignature { title, artist, album, durationSeconds, cacheKey }`,
  `NowPlayingState { track, sourceAppName, status: .playing/.paused/.stopped,
  elapsedSeconds, capturedAt }`, `LyricLine { timestamp, text }`,
  `LyricsResult` enum `.synced([LyricLine])`, `.plain(String)`, `.notFound`.
  All later tasks depend on these exact names/cases.

- [ ] **Step 1: Write the failing test for `TrackSignature.cacheKey`**

```swift
// Tests/lyricsbarTests/TrackSignatureTests.swift
import Testing
@testable import lyricsbar

@Test func cacheKeyNormalizesCaseAndWhitespace() {
    let a = TrackSignature(title: " Hello World ", artist: "The Band", album: nil, durationSeconds: nil)
    let b = TrackSignature(title: "hello world", artist: "the band", album: "Different Album", durationSeconds: 200)
    #expect(a.cacheKey == b.cacheKey)
}

@Test func cacheKeyDiffersForDifferentTracks() {
    let a = TrackSignature(title: "Song A", artist: "Artist", album: nil, durationSeconds: nil)
    let b = TrackSignature(title: "Song B", artist: "Artist", album: nil, durationSeconds: nil)
    #expect(a.cacheKey != b.cacheKey)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TrackSignatureTests`
Expected: FAIL — `TrackSignature` not defined.

- [ ] **Step 3: Write the models**

```swift
// Sources/lyricsbar/Models/TrackSignature.swift
import Foundation

struct TrackSignature: Hashable, Codable {
    let title: String
    let artist: String
    let album: String?
    let durationSeconds: Int?

    var cacheKey: String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedArtist)::\(normalizedTitle)"
    }
}
```

```swift
// Sources/lyricsbar/Models/NowPlayingState.swift
import Foundation

struct NowPlayingState: Equatable {
    enum PlaybackStatus: Equatable {
        case playing
        case paused
        case stopped
    }

    let track: TrackSignature
    let sourceAppName: String
    let status: PlaybackStatus
    let elapsedSeconds: Double
    let capturedAt: Date
}
```

```swift
// Sources/lyricsbar/Models/LyricLine.swift
import Foundation

struct LyricLine: Equatable, Codable {
    let timestamp: TimeInterval
    let text: String
}
```

```swift
// Sources/lyricsbar/Models/LyricsResult.swift
enum LyricsResult: Equatable {
    case synced([LyricLine])
    case plain(String)
    case notFound
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter TrackSignatureTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/Models Tests/lyricsbarTests/TrackSignatureTests.swift
git commit -m "feat: add core track/lyrics models"
```

---

### Task 3: LRC lyrics parser

**Files:**
- Create: `Sources/lyricsbar/Lyrics/LRCParser.swift`
- Test: `Tests/lyricsbarTests/LRCParserTests.swift`

**Interfaces:**
- Consumes: `LyricLine` from Task 2.
- Produces: `enum LRCParser { static func parse(_ raw: String) -> [LyricLine] }`,
  sorted ascending by `timestamp`. Used by Task 4's `LRCLibProvider`.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/lyricsbarTests/LRCParserTests.swift
import Testing
@testable import lyricsbar

@Test func parsesTimestampedLines() {
    let raw = "[00:12.00]Line one\n[00:17.50]Line two\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 2)
    #expect(lines[0].timestamp == 12.0)
    #expect(lines[0].text == "Line one")
    #expect(lines[1].timestamp == 17.5)
    #expect(lines[1].text == "Line two")
}

@Test func sortsLinesByTimestampRegardlessOfInputOrder() {
    let raw = "[01:00.00]Second\n[00:05.00]First\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.map(\.text) == ["First", "Second"])
}

@Test func skipsLinesWithoutTimestamps() {
    let raw = "[ti:Some Title]\n[ar:Some Artist]\n[00:01.00]Real lyric\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 1)
    #expect(lines[0].text == "Real lyric")
}

@Test func skipsEmptyLyricAfterTimestamp() {
    let raw = "[00:01.00]   \n[00:02.00]Real lyric\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 1)
    #expect(lines[0].text == "Real lyric")
}

@Test func duplicatesLineForMultipleTimestampTags() {
    let raw = "[00:01.00][00:30.00]Chorus\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 2)
    #expect(lines.allSatisfy { $0.text == "Chorus" })
    #expect(lines.map(\.timestamp) == [1.0, 30.0])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LRCParserTests`
Expected: FAIL — `LRCParser` not defined.

- [ ] **Step 3: Write the parser**

```swift
// Sources/lyricsbar/Lyrics/LRCParser.swift
import Foundation

enum LRCParser {
    private static let tagPattern = #"\[(\d{1,2}):(\d{2}(?:\.\d{1,3})?)\]"#

    static func parse(_ raw: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return [] }
        var results: [LyricLine] = []

        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let nsrange = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: nsrange)
            guard let lastMatch = matches.last else { continue }

            var timestamps: [TimeInterval] = []
            for match in matches {
                guard let minutesRange = Range(match.range(at: 1), in: line),
                      let secondsRange = Range(match.range(at: 2), in: line),
                      let minutes = Double(line[minutesRange]),
                      let seconds = Double(line[secondsRange]) else { continue }
                timestamps.append(minutes * 60 + seconds)
            }
            guard !timestamps.isEmpty else { continue }

            let textStartIndex = line.index(line.startIndex, offsetBy: lastMatch.range.location + lastMatch.range.length)
            let text = String(line[textStartIndex...]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            for timestamp in timestamps {
                results.append(LyricLine(timestamp: timestamp, text: text))
            }
        }

        return results.sorted { $0.timestamp < $1.timestamp }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LRCParserTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/Lyrics/LRCParser.swift Tests/lyricsbarTests/LRCParserTests.swift
git commit -m "feat: add LRC lyrics parser"
```

---

### Task 4: LRCLIB lyrics provider

**Files:**
- Create: `Sources/lyricsbar/Lyrics/LyricsProvider.swift`
- Create: `Sources/lyricsbar/Lyrics/LRCLibProvider.swift`
- Test: `Tests/lyricsbarTests/LRCLibProviderTests.swift`

**Interfaces:**
- Consumes: `TrackSignature`, `LyricsResult`, `LRCParser.parse` from Tasks 2-3.
- Produces: `protocol LyricsProvider { func lyrics(for track: TrackSignature) async -> LyricsResult }`
  and `struct LRCLibProvider: LyricsProvider` (default provider used by
  `AppDelegate` in Task 12). Also produces `protocol HTTPClient { func data(for request: URLRequest) async throws -> (Data, URLResponse) }`
  used by tests to fake the network.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/lyricsbarTests/LRCLibProviderTests.swift
import Foundation
import Testing
@testable import lyricsbar

private struct FakeHTTPClient: HTTPClient {
    let statusCode: Int
    let body: String

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (body.data(using: .utf8)!, response)
    }
}

@Test func returnsSyncedLyricsWhenPresent() async {
    let json = #"{"syncedLyrics":"[00:01.00]Hello\n","plainLyrics":"Hello"}"#
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 200, body: json))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    guard case .synced(let lines) = result else {
        Issue.record("expected synced result")
        return
    }
    #expect(lines == [LyricLine(timestamp: 1.0, text: "Hello")])
}

@Test func fallsBackToPlainLyricsWhenNoSyncAvailable() async {
    let json = #"{"syncedLyrics":null,"plainLyrics":"Just words"}"#
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 200, body: json))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .plain("Just words"))
}

@Test func returnsNotFoundOn404() async {
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 404, body: "{}"))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .notFound)
}

@Test func returnsNotFoundOnMalformedJSON() async {
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 200, body: "not json"))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .notFound)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LRCLibProviderTests`
Expected: FAIL — `LyricsProvider`/`LRCLibProvider`/`HTTPClient` not defined.

- [ ] **Step 3: Write the provider**

```swift
// Sources/lyricsbar/Lyrics/LyricsProvider.swift
import Foundation

protocol LyricsProvider {
    func lyrics(for track: TrackSignature) async -> LyricsResult
}

protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
```

```swift
// Sources/lyricsbar/Lyrics/LRCLibProvider.swift
import Foundation

struct LRCLibProvider: LyricsProvider {
    private let httpClient: HTTPClient
    private let baseURL: URL

    init(
        httpClient: HTTPClient = URLSession.shared,
        baseURL: URL = URL(string: "https://lrclib.net/api/get")!
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    private struct Response: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    func lyrics(for track: TrackSignature) async -> LyricsResult {
        guard let url = requestURL(for: track) else { return .notFound }

        do {
            let (data, response) = try await httpClient.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .notFound
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            if let synced = decoded.syncedLyrics, !synced.isEmpty {
                return .synced(LRCParser.parse(synced))
            }
            if let plain = decoded.plainLyrics, !plain.isEmpty {
                return .plain(plain)
            }
            return .notFound
        } catch {
            return .notFound
        }
    }

    private func requestURL(for track: TrackSignature) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        var items = [
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "track_name", value: track.title),
        ]
        if let album = track.album { items.append(URLQueryItem(name: "album_name", value: album)) }
        if let duration = track.durationSeconds { items.append(URLQueryItem(name: "duration", value: String(duration))) }
        components.queryItems = items
        return components.url
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LRCLibProviderTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/Lyrics/LyricsProvider.swift Sources/lyricsbar/Lyrics/LRCLibProvider.swift Tests/lyricsbarTests/LRCLibProviderTests.swift
git commit -m "feat: add LRCLIB-backed lyrics provider"
```

---

### Task 5: Disk lyrics cache

**Files:**
- Create: `Sources/lyricsbar/Lyrics/LyricsCache.swift`
- Test: `Tests/lyricsbarTests/LyricsCacheTests.swift`

**Interfaces:**
- Consumes: `TrackSignature`, `LyricsResult`, `LyricLine` from Task 2.
- Produces: `final class LyricsCache { init(directory: URL, fileManager: FileManager = .default); func store(_ result: LyricsResult, for track: TrackSignature); func load(for track: TrackSignature) -> LyricsResult? }`.
  Used by `PlayerViewModel` (Task 8) and `AppDelegate` (Task 12).

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/lyricsbarTests/LyricsCacheTests.swift
import Foundation
import Testing
@testable import lyricsbar

private func makeTempCache() -> LyricsCache {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return LyricsCache(directory: dir)
}

@Test func storesAndLoadsSyncedLyrics() {
    let cache = makeTempCache()
    let track = TrackSignature(title: "Song", artist: "Artist", album: nil, durationSeconds: nil)
    let result = LyricsResult.synced([LyricLine(timestamp: 1.0, text: "Hi")])
    cache.store(result, for: track)
    #expect(cache.load(for: track) == result)
}

@Test func storesAndLoadsPlainLyrics() {
    let cache = makeTempCache()
    let track = TrackSignature(title: "Song2", artist: "Artist2", album: nil, durationSeconds: nil)
    cache.store(.plain("Words"), for: track)
    #expect(cache.load(for: track) == .plain("Words"))
}

@Test func returnsNilForUnseenTrack() {
    let cache = makeTempCache()
    let track = TrackSignature(title: "Never Cached", artist: "Nobody", album: nil, durationSeconds: nil)
    #expect(cache.load(for: track) == nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LyricsCacheTests`
Expected: FAIL — `LyricsCache` not defined.

- [ ] **Step 3: Write the cache**

```swift
// Sources/lyricsbar/Lyrics/LyricsCache.swift
import Foundation

final class LyricsCache {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private struct Payload: Codable {
        let kind: String
        let lines: [LyricLine]?
        let plainText: String?
    }

    private func fileURL(for track: TrackSignature) -> URL {
        let safeKey = track.cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? track.cacheKey
        return directory.appendingPathComponent("\(safeKey).json")
    }

    func store(_ result: LyricsResult, for track: TrackSignature) {
        let payload: Payload
        switch result {
        case .synced(let lines):
            payload = Payload(kind: "synced", lines: lines, plainText: nil)
        case .plain(let text):
            payload = Payload(kind: "plain", lines: nil, plainText: text)
        case .notFound:
            payload = Payload(kind: "notFound", lines: nil, plainText: nil)
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL(for: track), options: .atomic)
    }

    func load(for track: TrackSignature) -> LyricsResult? {
        guard let data = try? Data(contentsOf: fileURL(for: track)),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        switch payload.kind {
        case "synced": return .synced(payload.lines ?? [])
        case "plain": return .plain(payload.plainText ?? "")
        case "notFound": return .notFound
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LyricsCacheTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/Lyrics/LyricsCache.swift Tests/lyricsbarTests/LyricsCacheTests.swift
git commit -m "feat: add on-disk lyrics cache"
```

---

### Task 6: Music source abstraction + system Now Playing bridge

**Files:**
- Create: `Sources/lyricsbar/MediaSources/MusicSource.swift`
- Create: `Sources/lyricsbar/MediaSources/MediaRemoteClient.swift`
- Create: `Sources/lyricsbar/MediaSources/SystemNowPlayingSource.swift`
- Test: `Tests/lyricsbarTests/SystemNowPlayingSourceTests.swift`

**Interfaces:**
- Consumes: `NowPlayingState`, `TrackSignature` from Task 2.
- Produces: `protocol MusicSource { var nowPlayingUpdates: AsyncStream<NowPlayingState?> { get }; func play(); func pause(); func next(); func previous() }`,
  `protocol MediaRemoteClient`, `enum MediaRemoteCommand`,
  `final class SystemNowPlayingSource: MusicSource`, and
  `final class LiveMediaRemoteClient: MediaRemoteClient` (the real private-framework
  bridge, wired up in `AppDelegate` in Task 12). `PlayerViewModel` (Task 8)
  depends only on the `MusicSource` protocol.

**Important note on the private framework:** `LiveMediaRemoteClient` calls
undocumented `MediaRemote.framework` symbols (the same technique the
open-source `nowplaying-cli` tool uses:
https://github.com/kirtan-shah/nowplaying-cli). Before wiring this into the
app in Task 12, open that repo's source and confirm the exact notification
name, info-dictionary keys, and command integer codes still match — Apple
can change private symbols between OS versions without notice. The code
below uses the values that tool currently documents; if a future macOS
version changes them, only this file needs updating, because `MusicSource`
and `PlayerViewModel` never see raw MediaRemote details.

- [ ] **Step 1: Write the failing tests using a fake client**

```swift
// Tests/lyricsbarTests/SystemNowPlayingSourceTests.swift
import Foundation
import Testing
@testable import lyricsbar

private final class FakeMediaRemoteClient: MediaRemoteClient {
    var registeredHandler: ((NowPlayingState?) -> Void)?
    private(set) var sentCommands: [MediaRemoteCommand] = []

    func registerForNowPlayingNotifications(handler: @escaping (NowPlayingState?) -> Void) {
        registeredHandler = handler
    }

    func sendCommand(_ command: MediaRemoteCommand) {
        sentCommands.append(command)
    }
}

@Test func forwardsMediaRemoteUpdatesThroughAsyncStream() async {
    let client = FakeMediaRemoteClient()
    let source = SystemNowPlayingSource(client: client)

    var iterator = source.nowPlayingUpdates.makeAsyncIterator()
    // Registering the stream triggers registerForNowPlayingNotifications lazily,
    // so pump once to ensure the handler is captured before we push a value.
    let track = TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil)
    let state = NowPlayingState(track: track, sourceAppName: "System", status: .playing, elapsedSeconds: 0, capturedAt: Date())

    let task = Task { await iterator.next() }
    // Give the AsyncStream's onStart a chance to run and register the handler.
    try? await Task.sleep(nanoseconds: 10_000_000)
    client.registeredHandler?(state)

    let received = await task.value
    #expect(received == state)
}

@Test func forwardsCommandsToClient() {
    let client = FakeMediaRemoteClient()
    let source = SystemNowPlayingSource(client: client)
    source.play()
    source.pause()
    source.next()
    source.previous()
    #expect(client.sentCommands == [.play, .pause, .next, .previous])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SystemNowPlayingSourceTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write the protocol and source**

```swift
// Sources/lyricsbar/MediaSources/MusicSource.swift
import Foundation

protocol MusicSource {
    var nowPlayingUpdates: AsyncStream<NowPlayingState?> { get }
    func play()
    func pause()
    func next()
    func previous()
}
```

```swift
// Sources/lyricsbar/MediaSources/MediaRemoteClient.swift
import Foundation

enum MediaRemoteCommand {
    case play
    case pause
    case next
    case previous
}

protocol MediaRemoteClient {
    func registerForNowPlayingNotifications(handler: @escaping (NowPlayingState?) -> Void)
    func sendCommand(_ command: MediaRemoteCommand)
}

/// Bridges Apple's private MediaRemote.framework, the same technique used by
/// the open-source `nowplaying-cli` tool. See the note in Task 6 of the
/// implementation plan before changing the symbol/key names below.
final class LiveMediaRemoteClient: MediaRemoteClient {
    private typealias GetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias RegisterForNotificationsFunction = @convention(c) (DispatchQueue) -> Void
    private typealias SendCommandFunction = @convention(c) (Int, AnyObject?) -> Bool

    private let handle: UnsafeMutableRawPointer
    private var updateHandler: ((NowPlayingState?) -> Void)?

    init?() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ) else { return nil }
        self.handle = handle
    }

    deinit {
        dlclose(handle)
    }

    func registerForNowPlayingNotifications(handler: @escaping (NowPlayingState?) -> Void) {
        updateHandler = handler
        guard let registerPtr = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
              let getInfoPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { return }

        let register = unsafeBitCast(registerPtr, to: RegisterForNotificationsFunction.self)
        register(DispatchQueue.main)

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchNowPlayingInfo(using: getInfoPtr)
        }
        fetchNowPlayingInfo(using: getInfoPtr)
    }

    private func fetchNowPlayingInfo(using getInfoPtr: UnsafeMutableRawPointer) {
        let getInfo = unsafeBitCast(getInfoPtr, to: GetNowPlayingInfoFunction.self)
        getInfo(DispatchQueue.main) { [weak self] info in
            self?.updateHandler?(Self.mapToState(info))
        }
    }

    static func mapToState(_ info: [String: Any]) -> NowPlayingState? {
        guard let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String else { return nil }
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist"
        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
        let durationSeconds = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double).map { Int($0) }
        let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
        let isPlaying = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
        let track = TrackSignature(title: title, artist: artist, album: album, durationSeconds: durationSeconds)
        return NowPlayingState(
            track: track,
            sourceAppName: "System",
            status: isPlaying ? .playing : .paused,
            elapsedSeconds: elapsed,
            capturedAt: Date()
        )
    }

    func sendCommand(_ command: MediaRemoteCommand) {
        guard let sendPtr = dlsym(handle, "MRMediaRemoteSendCommand") else { return }
        let send = unsafeBitCast(sendPtr, to: SendCommandFunction.self)
        let code: Int
        switch command {
        case .play: code = 0
        case .pause: code = 1
        case .next: code = 4
        case .previous: code = 5
        }
        _ = send(code, nil)
    }
}
```

```swift
// Sources/lyricsbar/MediaSources/SystemNowPlayingSource.swift
import Foundation

final class SystemNowPlayingSource: MusicSource {
    private let client: MediaRemoteClient
    private var continuation: AsyncStream<NowPlayingState?>.Continuation?

    lazy var nowPlayingUpdates: AsyncStream<NowPlayingState?> = AsyncStream { [weak self] continuation in
        guard let self else { return }
        self.continuation = continuation
        self.client.registerForNowPlayingNotifications { state in
            continuation.yield(state)
        }
    }

    init(client: MediaRemoteClient) {
        self.client = client
    }

    func play() { client.sendCommand(.play) }
    func pause() { client.sendCommand(.pause) }
    func next() { client.sendCommand(.next) }
    func previous() { client.sendCommand(.previous) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SystemNowPlayingSourceTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/MediaSources Tests/lyricsbarTests/SystemNowPlayingSourceTests.swift
git commit -m "feat: add MusicSource protocol and MediaRemote-backed implementation"
```

---

### Task 7: Theme model and ThemeManager

**Files:**
- Create: `Sources/lyricsbar/Theming/Theme.swift`
- Create: `Sources/lyricsbar/Theming/ThemeManager.swift`
- Test: `Tests/lyricsbarTests/ThemeManagerTests.swift`

**Interfaces:**
- Produces: `struct Theme { id, name, backgroundColors: [String], accentColorHex: String, blurIntensity: Double, motif: Theme.Motif }`
  with `static let builtIn: [Theme]` containing exactly `.auroraGlass` and
  `.neonArcade`; `final class ThemeManager: ObservableObject { @Published private(set) var current: Theme; func select(_ theme: Theme) }`.
  Used by `PlayerViewModel`'s consumers in Overlay (Task 10) and MenuBar
  (Task 12).

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/lyricsbarTests/ThemeManagerTests.swift
import Foundation
import Testing
@testable import lyricsbar

@Test func exposesExactlyTwoBuiltInThemes() {
    #expect(Theme.builtIn.count == 2)
    #expect(Theme.builtIn.map(\.id) == ["aurora-glass", "neon-arcade"])
}

@Test func defaultsToAuroraGlassWhenNothingPersisted() {
    let defaults = UserDefaults(suiteName: "lyricsbar-tests-\(UUID().uuidString)")!
    let manager = ThemeManager(defaults: defaults)
    #expect(manager.current.id == "aurora-glass")
}

@Test func selectingThemePersistsAcrossInstances() {
    let suiteName = "lyricsbar-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let manager = ThemeManager(defaults: defaults)
    manager.select(.neonArcade)
    #expect(manager.current.id == "neon-arcade")

    let reloaded = ThemeManager(defaults: defaults)
    #expect(reloaded.current.id == "neon-arcade")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ThemeManagerTests`
Expected: FAIL — `Theme`/`ThemeManager` not defined.

- [ ] **Step 3: Write the theme model and manager**

```swift
// Sources/lyricsbar/Theming/Theme.swift
struct Theme: Identifiable, Equatable {
    enum Motif: Equatable {
        case none
        case neonGrid
    }

    let id: String
    let name: String
    let backgroundColors: [String]
    let accentColorHex: String
    let blurIntensity: Double
    let motif: Motif

    static let auroraGlass = Theme(
        id: "aurora-glass",
        name: "Aurora Glass",
        backgroundColors: ["#1C1C1E", "#2C2C2E"],
        accentColorHex: "#5AC8FA",
        blurIntensity: 0.6,
        motif: .none
    )

    static let neonArcade = Theme(
        id: "neon-arcade",
        name: "Neon Arcade",
        backgroundColors: ["#0D0221", "#190A33"],
        accentColorHex: "#FF2E92",
        blurIntensity: 0.8,
        motif: .neonGrid
    )

    static let builtIn: [Theme] = [.auroraGlass, .neonArcade]
}
```

```swift
// Sources/lyricsbar/Theming/ThemeManager.swift
import Foundation

final class ThemeManager: ObservableObject {
    @Published private(set) var current: Theme
    private let defaults: UserDefaults
    private static let key = "lyricsbar.selectedThemeID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedID = defaults.string(forKey: Self.key)
        self.current = Theme.builtIn.first { $0.id == savedID } ?? .auroraGlass
    }

    func select(_ theme: Theme) {
        current = theme
        defaults.set(theme.id, forKey: Self.key)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ThemeManagerTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/Theming Tests/lyricsbarTests/ThemeManagerTests.swift
git commit -m "feat: add Theme model and persisted ThemeManager"
```

---

### Task 8: PlayerViewModel

**Files:**
- Create: `Sources/lyricsbar/ViewModel/PlayerViewModel.swift`
- Test: `Tests/lyricsbarTests/PlayerViewModelTests.swift`

**Interfaces:**
- Consumes: `MusicSource` (Task 6), `LyricsProvider` (Task 4), `LyricsCache`
  (Task 5), `NowPlayingState`/`LyricsResult`/`LyricLine` (Task 2).
- Produces: `@MainActor final class PlayerViewModel: ObservableObject { @Published private(set) var nowPlaying: NowPlayingState?; @Published private(set) var lyrics: LyricsResult; @Published private(set) var currentLineIndex: Int?; init(musicSource:lyricsProvider:cache:); func start(); func stop(); func playPause(); func next(); func previous() }`.
  Used by Overlay views (Task 10) and `AppDelegate` (Task 12).

- [ ] **Step 1: Write the failing tests using fakes**

```swift
// Tests/lyricsbarTests/PlayerViewModelTests.swift
import Foundation
import Testing
@testable import lyricsbar

private final class FakeMusicSource: MusicSource {
    private let (stream, continuation) = AsyncStream<NowPlayingState?>.makeStream()
    var nowPlayingUpdates: AsyncStream<NowPlayingState?> { stream }
    private(set) var playCalls = 0
    private(set) var pauseCalls = 0
    private(set) var nextCalls = 0
    private(set) var previousCalls = 0

    func push(_ state: NowPlayingState?) { continuation.yield(state) }
    func play() { playCalls += 1 }
    func pause() { pauseCalls += 1 }
    func next() { nextCalls += 1 }
    func previous() { previousCalls += 1 }
}

private final class FakeLyricsProvider: LyricsProvider {
    private(set) var requestedTracks: [TrackSignature] = []
    var resultToReturn: LyricsResult = .notFound

    func lyrics(for track: TrackSignature) async -> LyricsResult {
        requestedTracks.append(track)
        return resultToReturn
    }
}

private func track(_ title: String, elapsed: Double, status: NowPlayingState.PlaybackStatus = .playing) -> NowPlayingState {
    NowPlayingState(
        track: TrackSignature(title: title, artist: "Artist", album: nil, durationSeconds: nil),
        sourceAppName: "Safari",
        status: status,
        elapsedSeconds: elapsed,
        capturedAt: Date()
    )
}

@Test func fetchesAndCachesLyricsForNewTrack() async throws {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    provider.resultToReturn = .synced([LyricLine(timestamp: 0, text: "Line")])
    let cache = LyricsCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))

    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache)
    viewModel.start()

    source.push(track("Song A", elapsed: 0))
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(provider.requestedTracks.count == 1)
    #expect(viewModel.lyrics == .synced([LyricLine(timestamp: 0, text: "Line")]))
    viewModel.stop()
}

@Test func doesNotRefetchLyricsForSameTrack() async throws {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    provider.resultToReturn = .plain("Words")
    let cache = LyricsCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))

    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache)
    viewModel.start()

    source.push(track("Song B", elapsed: 0))
    try await Task.sleep(nanoseconds: 50_000_000)
    source.push(track("Song B", elapsed: 5))
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(provider.requestedTracks.count == 1)
    viewModel.stop()
}

@Test func computesCurrentLineIndexFromElapsedTime() async throws {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    provider.resultToReturn = .synced([
        LyricLine(timestamp: 0, text: "First"),
        LyricLine(timestamp: 10, text: "Second"),
        LyricLine(timestamp: 20, text: "Third"),
    ])
    let cache = LyricsCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))

    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache)
    viewModel.start()

    source.push(track("Song C", elapsed: 12))
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(viewModel.currentLineIndex == 1)
    viewModel.stop()
}

@Test func playPauseTogglesBasedOnCurrentStatus() {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    let cache = LyricsCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache)

    viewModel.playPause()
    #expect(source.playCalls == 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PlayerViewModelTests`
Expected: FAIL — `PlayerViewModel` not defined.

- [ ] **Step 3: Write the view model**

```swift
// Sources/lyricsbar/ViewModel/PlayerViewModel.swift
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var nowPlaying: NowPlayingState?
    @Published private(set) var lyrics: LyricsResult = .notFound
    @Published private(set) var currentLineIndex: Int?

    private let musicSource: MusicSource
    private let lyricsProvider: LyricsProvider
    private let cache: LyricsCache
    private var listenTask: Task<Void, Never>?

    init(musicSource: MusicSource, lyricsProvider: LyricsProvider, cache: LyricsCache) {
        self.musicSource = musicSource
        self.lyricsProvider = lyricsProvider
        self.cache = cache
    }

    func start() {
        listenTask = Task { [weak self] in
            guard let self else { return }
            for await state in self.musicSource.nowPlayingUpdates {
                await self.handle(state)
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
    }

    private func handle(_ state: NowPlayingState?) async {
        let previousTrack = nowPlaying?.track
        nowPlaying = state
        guard let state else {
            lyrics = .notFound
            currentLineIndex = nil
            return
        }
        if state.track != previousTrack {
            if let cached = cache.load(for: state.track) {
                lyrics = cached
            } else {
                let fetched = await lyricsProvider.lyrics(for: state.track)
                lyrics = fetched
                cache.store(fetched, for: state.track)
            }
        }
        updateCurrentLine(elapsed: state.elapsedSeconds)
    }

    private func updateCurrentLine(elapsed: Double) {
        guard case .synced(let lines) = lyrics, !lines.isEmpty else {
            currentLineIndex = nil
            return
        }
        var index: Int?
        for (i, line) in lines.enumerated() where line.timestamp <= elapsed {
            index = i
        }
        currentLineIndex = index
    }

    func playPause() {
        if nowPlaying?.status == .playing {
            musicSource.pause()
        } else {
            musicSource.play()
        }
    }

    func next() { musicSource.next() }
    func previous() { musicSource.previous() }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PlayerViewModelTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/ViewModel Tests/lyricsbarTests/PlayerViewModelTests.swift
git commit -m "feat: add PlayerViewModel tying music source, lyrics, and cache together"
```

---

### Task 9: Notch-aware overlay geometry

**Files:**
- Create: `Sources/lyricsbar/Overlay/ScreenMetrics.swift`
- Create: `Sources/lyricsbar/Overlay/NotchGeometry.swift`
- Test: `Tests/lyricsbarTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces: `struct ScreenMetrics { frame: CGRect, notchLeftMaxX: CGFloat?, notchRightMinX: CGFloat? }` (plus an `NSScreen` initializer added in
  Task 10, once `AppKit` is in scope for overlay code) and
  `enum NotchGeometry { static func overlayFrame(for screen: ScreenMetrics, collapsedSize: CGSize) -> CGRect }`.
  Used by `OverlayWindowController` (Task 10).

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/lyricsbarTests/NotchGeometryTests.swift
import Foundation
import Testing
@testable import lyricsbar

@Test func centersOnScreenWhenNoNotchPresent() {
    let screen = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1000, height: 700), notchLeftMaxX: nil, notchRightMinX: nil)
    let frame = NotchGeometry.overlayFrame(for: screen, collapsedSize: CGSize(width: 220, height: 32))
    #expect(frame.width == 220)
    #expect(frame.midX == 500)
    #expect(frame.maxY == 700 - 4)
}

@Test func widensToFitNotchWhenPresent() {
    let screen = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1000, height: 700), notchLeftMaxX: 460, notchRightMinX: 540)
    let frame = NotchGeometry.overlayFrame(for: screen, collapsedSize: CGSize(width: 60, height: 32))
    // notch width (80) + 40 padding = 120, wider than the 60pt collapsed size
    #expect(frame.width == 120)
    #expect(frame.midX == 500)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotchGeometryTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write the geometry types**

```swift
// Sources/lyricsbar/Overlay/ScreenMetrics.swift
import Foundation

struct ScreenMetrics: Equatable {
    let frame: CGRect
    let notchLeftMaxX: CGFloat?
    let notchRightMinX: CGFloat?
}
```

```swift
// Sources/lyricsbar/Overlay/NotchGeometry.swift
import Foundation

enum NotchGeometry {
    static func overlayFrame(for screen: ScreenMetrics, collapsedSize: CGSize) -> CGRect {
        let notchWidth: CGFloat
        if let left = screen.notchLeftMaxX, let right = screen.notchRightMinX, right > left {
            notchWidth = right - left
        } else {
            notchWidth = 0
        }
        let width = max(collapsedSize.width, notchWidth + 40)
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - collapsedSize.height - 4
        return CGRect(x: x, y: y, width: width, height: collapsedSize.height)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NotchGeometryTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/Overlay/ScreenMetrics.swift Sources/lyricsbar/Overlay/NotchGeometry.swift Tests/lyricsbarTests/NotchGeometryTests.swift
git commit -m "feat: add notch-aware overlay geometry calculation"
```

---

### Task 10: Liquid-glass overlay UI and window controller

**Files:**
- Create: `Sources/lyricsbar/Overlay/ColorHex.swift`
- Create: `Sources/lyricsbar/Overlay/VisualEffectBlur.swift`
- Create: `Sources/lyricsbar/Overlay/NeonGridMotif.swift`
- Create: `Sources/lyricsbar/Overlay/LiquidGlassBackground.swift`
- Create: `Sources/lyricsbar/Overlay/CollapsedPillView.swift`
- Create: `Sources/lyricsbar/Overlay/ExpandedLyricsPanelView.swift`
- Create: `Sources/lyricsbar/Overlay/OverlayWindowController.swift`
- Modify: `Sources/lyricsbar/Overlay/ScreenMetrics.swift` (add `NSScreen`
  initializer)
- Test: none — AppKit windows/screens aren't unit-testable outside a GUI
  session; this task is verified manually (see Step 6).

**Interfaces:**
- Consumes: `PlayerViewModel` (Task 8), `Theme`/`ThemeManager` (Task 7),
  `ScreenMetrics`/`NotchGeometry` (Task 9).
- Produces: `@MainActor final class OverlayWindowController { init(viewModel: PlayerViewModel, themeManager: ThemeManager); var showOnAllDisplays: Bool; func start() }`.
  Used by `AppDelegate` (Task 12).

- [ ] **Step 1: Add the `NSScreen` initializer to `ScreenMetrics`**

```swift
// Append to Sources/lyricsbar/Overlay/ScreenMetrics.swift
import AppKit

extension ScreenMetrics {
    init(screen: NSScreen) {
        frame = screen.frame
        notchLeftMaxX = screen.auxiliaryTopLeftArea.map { $0.maxX }
        notchRightMinX = screen.auxiliaryTopRightArea.map { $0.minX }
    }
}
```

(Note: this duplicates the `import Foundation` file with an `import AppKit`
extension — keep both imports at the top of the file: `import Foundation`
and `import AppKit`.)

- [ ] **Step 2: Write hex color, blur, and motif helpers**

```swift
// Sources/lyricsbar/Overlay/ColorHex.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

```swift
// Sources/lyricsbar/Overlay/VisualEffectBlur.swift
import AppKit
import SwiftUI

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
```

```swift
// Sources/lyricsbar/Overlay/NeonGridMotif.swift
import SwiftUI

struct NeonGridMotif: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 1)
                x += spacing
            }
        }
    }
}
```

- [ ] **Step 3: Write the liquid-glass background and pill/panel views**

```swift
// Sources/lyricsbar/Overlay/LiquidGlassBackground.swift
import SwiftUI

struct LiquidGlassBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundColors.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(theme.blurIntensity)
            if theme.motif == .neonGrid {
                NeonGridMotif(color: Color(hex: theme.accentColorHex))
            }
        }
    }
}
```

```swift
// Sources/lyricsbar/Overlay/CollapsedPillView.swift
import SwiftUI

struct CollapsedPillView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme

    var body: some View {
        ZStack {
            LiquidGlassBackground(theme: theme)
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .foregroundStyle(Color(hex: theme.accentColorHex))
                Text(currentLineText)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
        }
        .clipShape(Capsule())
    }

    private var currentLineText: String {
        if case .synced(let lines) = viewModel.lyrics, let index = viewModel.currentLineIndex {
            return lines[index].text
        }
        return viewModel.nowPlaying?.track.title ?? "Nothing playing"
    }
}
```

```swift
// Sources/lyricsbar/Overlay/ExpandedLyricsPanelView.swift
import SwiftUI

struct ExpandedLyricsPanelView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme

    var body: some View {
        ZStack {
            LiquidGlassBackground(theme: theme)
            VStack(spacing: 12) {
                Text(viewModel.nowPlaying?.track.title ?? "Nothing playing")
                    .font(.headline)
                Text(viewModel.nowPlaying?.sourceAppName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(lyricLines.enumerated()), id: \.offset) { index, line in
                                Text(line.text)
                                    .font(index == viewModel.currentLineIndex ? .title3.bold() : .body)
                                    .foregroundStyle(
                                        index == viewModel.currentLineIndex
                                            ? Color(hex: theme.accentColorHex)
                                            : .white.opacity(0.6)
                                    )
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: viewModel.currentLineIndex) { _, newValue in
                        guard let newValue else { return }
                        withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                    }
                }
                HStack(spacing: 24) {
                    Button(action: viewModel.previous) { Image(systemName: "backward.fill") }
                    Button(action: viewModel.playPause) {
                        Image(systemName: viewModel.nowPlaying?.status == .playing ? "pause.fill" : "play.fill")
                    }
                    Button(action: viewModel.next) { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var lyricLines: [LyricLine] {
        if case .synced(let lines) = viewModel.lyrics { return lines }
        return []
    }
}
```

- [ ] **Step 4: Write the per-screen window controller**

```swift
// Sources/lyricsbar/Overlay/OverlayWindowController.swift
import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController: NSObject {
    private var panels: [ObjectIdentifier: NSPanel] = [:]
    private let viewModel: PlayerViewModel
    private let themeManager: ThemeManager
    var showOnAllDisplays = true {
        didSet { rebuildPanels() }
    }

    init(viewModel: PlayerViewModel, themeManager: ThemeManager) {
        self.viewModel = viewModel
        self.themeManager = themeManager
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildPanels),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func start() {
        rebuildPanels()
    }

    @objc private func rebuildPanels() {
        for panel in panels.values { panel.orderOut(nil) }
        panels.removeAll()

        let targetScreens = showOnAllDisplays ? NSScreen.screens : NSScreen.main.map { [$0] } ?? []
        let collapsedSize = CGSize(width: 220, height: 32)

        for screen in targetScreens {
            let metrics = ScreenMetrics(screen: screen)
            let frame = NotchGeometry.overlayFrame(for: metrics, collapsedSize: collapsedSize)

            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true

            let hosting = NSHostingView(
                rootView: CollapsedPillView(viewModel: viewModel, theme: themeManager.current)
            )
            hosting.frame = NSRect(origin: .zero, size: frame.size)
            panel.contentView = hosting
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()

            panels[ObjectIdentifier(screen)] = panel
        }
    }
}
```

- [ ] **Step 5: Build the project**

Run: `swift build`
Expected: builds with no errors.

- [ ] **Step 6: Manual smoke test**

Run: `swift run &`, then visually confirm:
1. A small transparent pill appears near the top-center of the main
   display, showing "Nothing playing".
2. If a second display is connected, the pill also appears there.
3. Clicking through the pill's area still reaches whatever app is behind it
   (it's `ignoresMouseEvents = true` while collapsed).

Stop the run afterward: `kill %1`.

- [ ] **Step 7: Commit**

```bash
git add Sources/lyricsbar/Overlay
git commit -m "feat: add liquid-glass overlay views and per-screen window controller"
```

---

### Task 11: Autostart (Launch at Login) manager

**Files:**
- Create: `Sources/lyricsbar/Support/AutostartManager.swift`
- Test: `Tests/lyricsbarTests/AutostartManagerTests.swift`

**Interfaces:**
- Produces: `final class AutostartManager { init(launchAgentsDirectory: URL = ..., fileManager: FileManager = .default, executablePath: @escaping () -> String = ...); var isEnabled: Bool; func plistContents() -> String }`.
  Used by `StatusItemController` (Task 12).

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/lyricsbarTests/AutostartManagerTests.swift
import Foundation
import Testing
@testable import lyricsbar

private func makeManager(in directory: URL) -> AutostartManager {
    AutostartManager(launchAgentsDirectory: directory, executablePath: { "/usr/local/bin/lyricsbar" })
}

@Test func startsDisabledWhenNoPlistExists() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let manager = makeManager(in: dir)
    #expect(manager.isEnabled == false)
}

@Test func enablingWritesPlistWithExecutablePath() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let manager = makeManager(in: dir)
    manager.isEnabled = true
    #expect(manager.isEnabled == true)

    let plistPath = dir.appendingPathComponent("com.lyricsbar.autostart.plist")
    let contents = try! String(contentsOf: plistPath, encoding: .utf8)
    #expect(contents.contains("/usr/local/bin/lyricsbar"))
}

@Test func disablingRemovesPlist() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let manager = makeManager(in: dir)
    manager.isEnabled = true
    manager.isEnabled = false
    #expect(manager.isEnabled == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AutostartManagerTests`
Expected: FAIL — `AutostartManager` not defined.

- [ ] **Step 3: Write the manager**

```swift
// Sources/lyricsbar/Support/AutostartManager.swift
import Foundation

final class AutostartManager {
    private let label = "com.lyricsbar.autostart"
    private let launchAgentsDirectory: URL
    private let fileManager: FileManager
    private let executablePath: () -> String

    init(
        launchAgentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents"),
        fileManager: FileManager = .default,
        executablePath: @escaping () -> String = { Bundle.main.executablePath ?? "" }
    ) {
        self.launchAgentsDirectory = launchAgentsDirectory
        self.fileManager = fileManager
        self.executablePath = executablePath
    }

    private var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    var isEnabled: Bool {
        get { fileManager.fileExists(atPath: plistURL.path) }
        set {
            if newValue {
                write()
            } else {
                remove()
            }
        }
    }

    func plistContents() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath())</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }

    private func write() {
        try? fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
        try? plistContents().write(to: plistURL, atomically: true, encoding: .utf8)
    }

    private func remove() {
        try? fileManager.removeItem(at: plistURL)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AutostartManagerTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/Support/AutostartManager.swift Tests/lyricsbarTests/AutostartManagerTests.swift
git commit -m "feat: add Launch at Login autostart manager"
```

---

### Task 12: Menu bar controller and full app wiring

**Files:**
- Create: `Sources/lyricsbar/MenuBar/StatusItemController.swift`
- Modify: `Sources/lyricsbar/App/AppDelegate.swift` (replace the Task 1 stub
  with full wiring)
- Test: none — this task is integration wiring, verified by the manual
  smoke test in Step 3.

**Interfaces:**
- Consumes: `ThemeManager` (Task 7), `OverlayWindowController` (Task 10),
  `AutostartManager` (Task 11), `Theme.builtIn` (Task 7).
- Produces: fully wired `AppDelegate` used as the app's entry point.

- [ ] **Step 1: Write the status item controller**

```swift
// Sources/lyricsbar/MenuBar/StatusItemController.swift
import AppKit

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let themeManager: ThemeManager
    private let overlayController: OverlayWindowController
    private let autostartManager: AutostartManager

    init(
        themeManager: ThemeManager,
        overlayController: OverlayWindowController,
        autostartManager: AutostartManager
    ) {
        self.themeManager = themeManager
        self.overlayController = overlayController
        self.autostartManager = autostartManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "LyricsBar")
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let themeMenu = NSMenu()
        for theme in Theme.builtIn {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.id
            item.state = theme.id == themeManager.current.id ? .on : .off
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let displayModeItem = NSMenuItem(
            title: "Show on Active Display Only",
            action: #selector(toggleDisplayMode),
            keyEquivalent: ""
        )
        displayModeItem.target = self
        displayModeItem.state = overlayController.showOnAllDisplays ? .off : .on
        menu.addItem(displayModeItem)

        let autostartItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleAutostart), keyEquivalent: "")
        autostartItem.target = self
        autostartItem.state = autostartManager.isEnabled ? .on : .off
        menu.addItem(autostartItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit LyricsBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let theme = Theme.builtIn.first(where: { $0.id == id }) else { return }
        themeManager.select(theme)
        buildMenu()
    }

    @objc private func toggleDisplayMode() {
        overlayController.showOnAllDisplays.toggle()
        buildMenu()
    }

    @objc private func toggleAutostart() {
        autostartManager.isEnabled.toggle()
        buildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

- [ ] **Step 2: Replace the `AppDelegate` stub with full wiring**

```swift
// Sources/lyricsbar/App/AppDelegate.swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var overlayController: OverlayWindowController?
    private var viewModel: PlayerViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let mediaRemoteClient = LiveMediaRemoteClient() else {
            NSLog("LyricsBar: MediaRemote framework unavailable; now-playing detection disabled")
            return
        }

        let musicSource = SystemNowPlayingSource(client: mediaRemoteClient)
        let cacheDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LyricsBar/LyricsCache", isDirectory: true)
        let cache = LyricsCache(directory: cacheDirectory)
        let lyricsProvider = LRCLibProvider()

        let vm = PlayerViewModel(musicSource: musicSource, lyricsProvider: lyricsProvider, cache: cache)
        vm.start()
        viewModel = vm

        let themeManager = ThemeManager()
        let overlay = OverlayWindowController(viewModel: vm, themeManager: themeManager)
        overlay.start()
        overlayController = overlay

        let autostartManager = AutostartManager()
        statusItemController = StatusItemController(
            themeManager: themeManager,
            overlayController: overlay,
            autostartManager: autostartManager
        )
    }
}
```

- [ ] **Step 3: Build and run the full manual smoke test**

Run: `swift build`
Expected: builds with no errors.

Run: `swift run &`, then verify:
1. Menu bar shows the LyricsBar icon; clicking it shows Theme submenu (2
   themes), "Show on Active Display Only", "Launch at Login", and Quit.
2. Play any track in a browser tab at `music.youtube.com` (or Spotify/Apple
   Music) — within a few seconds the overlay pill updates to show the track
   title (lyrics may say "Nothing playing"/no sync if LRCLIB has no match,
   which is expected per the spec's documented limitation).
3. Selecting "Neon Arcade" from the Theme submenu changes the overlay's
   background/accent color.
4. Toggling "Launch at Login" creates/removes
   `~/Library/LaunchAgents/com.lyricsbar.autostart.plist` — confirm with
   `ls ~/Library/LaunchAgents/`.
5. Quit via the menu.

- [ ] **Step 4: Run the full test suite one more time**

Run: `swift test`
Expected: all tests from Tasks 2-9 and 11 PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/lyricsbar/MenuBar Sources/lyricsbar/App/AppDelegate.swift
git commit -m "feat: wire menu bar controller and full app startup"
```

---

## Explicitly out of scope for this plan (see spec §8)

- No login/session-token screen.
- No `ytmdesktop` companion API `MusicSource` implementation.
- No more than 2 themes.
- No non-macOS platform support.

These can be follow-up plans once this MVP is reviewed and working.
