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

    func lyrics(for track: TrackSignature) async -> LyricsResult {
        requestedTracks.append(track)
        return resultToReturn
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
