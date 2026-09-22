import Testing
@testable import echofloat

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
