import Foundation
import Testing
@testable import echofloat

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
    var queuedResults: [LyricsResult] = []

    func lyrics(for track: TrackSignature) async -> LyricsResult {
        requestedTracks.append(track)
        if !queuedResults.isEmpty {
            return queuedResults.removeFirst()
        }
        return resultToReturn
    }
}

private final class ControlledRetryLyricsProvider: LyricsProvider {
    private(set) var requestCount = 0
    private var continuations: [CheckedContinuation<LyricsResult, Never>] = []

    func lyrics(for track: TrackSignature) async -> LyricsResult {
        requestCount += 1
        if requestCount == 1 {
            return .unavailable
        }
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func completePending(with result: LyricsResult) {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume(returning: result) }
    }
}

private final class TrackControlledLyricsProvider: LyricsProvider {
    private(set) var requestedTracks: [TrackSignature] = []
    private var continuations: [String: CheckedContinuation<LyricsResult, Never>] = [:]

    func lyrics(for track: TrackSignature) async -> LyricsResult {
        requestedTracks.append(track)
        return await withCheckedContinuation { continuation in
            continuations[track.title] = continuation
        }
    }

    func complete(_ title: String, with result: LyricsResult) {
        continuations.removeValue(forKey: title)?.resume(returning: result)
    }
}

private func track(
    _ title: String,
    elapsed: Double,
    status: NowPlayingState.PlaybackStatus = .playing
) -> NowPlayingState {
    NowPlayingState(
        track: TrackSignature(title: title, artist: "Artist", album: nil, durationSeconds: nil),
        sourceAppName: "Safari",
        status: status,
        elapsedSeconds: elapsed,
        capturedAt: Date()
    )
}

@Test @MainActor func fetchesAndCachesLyricsForNewTrack() async throws {
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

@Test @MainActor func doesNotRefetchLyricsForSameTrack() async throws {
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

@Test @MainActor func computesCurrentLineIndexFromElapsedTime() async throws {
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

@Test @MainActor func playPauseTogglesBasedOnCurrentStatus() {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    let cache = LyricsCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache)

    viewModel.playPause()
    #expect(source.playCalls == 1)
}

@Test @MainActor func retriesTransientLyricsFailureForSameTrackWithoutCachingIt() async throws {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    provider.queuedResults = [.unavailable, .plain("Recovered")]
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LyricsCache(directory: directory)
    let song = track("Retry Song", elapsed: 0)
    let viewModel = PlayerViewModel(
        musicSource: source,
        lyricsProvider: provider,
        cache: cache,
        lyricsRetryBaseNanoseconds: 100_000_000,
        lyricsRetryMaximumNanoseconds: 100_000_000
    )
    viewModel.start()

    source.push(song)
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(viewModel.lyrics == .unavailable)
    #expect(cache.load(for: song.track) == nil)

    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(provider.requestedTracks.count == 2)
    #expect(viewModel.lyrics == .plain("Recovered"))
    #expect(cache.load(for: song.track) == .plain("Recovered"))
    viewModel.stop()
}

@Test @MainActor func doesNotCacheNotFoundResult() async throws {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    provider.resultToReturn = .notFound
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LyricsCache(directory: directory)
    let song = track("Missing Song", elapsed: 0)
    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache)
    viewModel.start()

    source.push(song)
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(viewModel.lyrics == .notFound)
    #expect(cache.load(for: song.track) == nil)
    viewModel.stop()
}

@Test @MainActor func sameTrackUpdatesDoNotCancelSlowTransientRetry() async throws {
    let source = FakeMusicSource()
    let provider = ControlledRetryLyricsProvider()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let viewModel = PlayerViewModel(
        musicSource: source,
        lyricsProvider: provider,
        cache: LyricsCache(directory: directory)
    )
    viewModel.start()

    source.push(track("Retry Song", elapsed: 0))
    try await Task.sleep(nanoseconds: 1_100_000_000)
    #expect(provider.requestCount == 2)

    source.push(track("Retry Song", elapsed: 1))
    source.push(track("Retry Song", elapsed: 2))
    source.push(track("Retry Song", elapsed: 3))
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(provider.requestCount == 2)
    provider.completePending(with: .plain("Recovered"))
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(viewModel.lyrics == .plain("Recovered"))
    viewModel.stop()
}

@Test @MainActor func newTrackCancelsOldRequestAndStartsImmediately() async throws {
    let source = FakeMusicSource()
    let provider = TrackControlledLyricsProvider()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let viewModel = PlayerViewModel(
        musicSource: source,
        lyricsProvider: provider,
        cache: LyricsCache(directory: directory)
    )
    viewModel.start()

    source.push(track("Old Song", elapsed: 0))
    try await Task.sleep(nanoseconds: 20_000_000)
    source.push(track("New Song", elapsed: 0))
    try await Task.sleep(nanoseconds: 20_000_000)

    #expect(provider.requestedTracks.map(\.title) == ["Old Song", "New Song"])
    provider.complete("Old Song", with: .plain("Old lyrics"))
    provider.complete("New Song", with: .plain("New lyrics"))
    try await Task.sleep(nanoseconds: 20_000_000)

    #expect(viewModel.lyrics == .plain("New lyrics"))
    viewModel.stop()
}

private final class SpyAppActivator: AppActivating {
    private(set) var activatedBundleIDs: [String] = []
    func activate(bundleID: String) { activatedBundleIDs.append(bundleID) }
}

@Test @MainActor func openSourceAppActivatesBundleForCurrentSource() async throws {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    let cache = LyricsCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let spy = SpyAppActivator()
    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache, activator: spy)
    viewModel.start()

    source.push(NowPlayingState(
        track: TrackSignature(title: "S", artist: "A", album: nil, durationSeconds: nil),
        sourceAppName: "Spotify",
        status: .playing,
        elapsedSeconds: 0,
        capturedAt: Date()
    ))
    try await Task.sleep(nanoseconds: 50_000_000)

    viewModel.openSourceApp()
    #expect(spy.activatedBundleIDs == ["com.spotify.client"])
    viewModel.stop()
}

@Test @MainActor func openSourceAppDoesNothingWhenNothingPlaying() {
    let source = FakeMusicSource()
    let provider = FakeLyricsProvider()
    let cache = LyricsCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let spy = SpyAppActivator()
    let viewModel = PlayerViewModel(musicSource: source, lyricsProvider: provider, cache: cache, activator: spy)

    viewModel.openSourceApp()
    #expect(spy.activatedBundleIDs.isEmpty)
}
