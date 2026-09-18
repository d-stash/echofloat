import Foundation
import Testing
@testable import echofloat

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
