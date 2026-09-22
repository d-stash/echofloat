import Foundation
import Testing
@testable import echofloat

private struct FakeHTTPClient: HTTPClient {
    enum Result {
        case response(statusCode: Int, body: String)
        case failure
    }

    /// Single canned response used regardless of the requested URL.
    let result: Result?
    /// Per-URL routing used by tests exercising both /api/get and /api/search.
    let handler: (@Sendable (URLRequest) -> Result)?

    init(statusCode: Int, body: String) {
        result = .response(statusCode: statusCode, body: body)
        handler = nil
    }

    init(result: Result) {
        self.result = result
        handler = nil
    }

    init(handler: @escaping @Sendable (URLRequest) -> Result) {
        self.result = nil
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let resolved = handler?(request) ?? result
        guard case .response(let statusCode, let body) = resolved else {
            throw URLError(.timedOut)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (body.data(using: .utf8)!, response)
    }
}

@Test @MainActor func returnsSyncedLyricsWhenPresent() async {
    let json = #"{"syncedLyrics":"[00:01.00]Hello\n","plainLyrics":"Hello"}"#
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 200, body: json))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    guard case .synced(let lines) = result else {
        Issue.record("expected synced result")
        return
    }
    #expect(lines == [LyricLine(timestamp: 1.0, text: "Hello")])
}

@Test @MainActor func fallsBackToPlainLyricsWhenNoSyncAvailable() async {
    let json = #"{"syncedLyrics":null,"plainLyrics":"Just words"}"#
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 200, body: json))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .plain("Just words"))
}

@Test @MainActor func returnsNotFoundOn404() async {
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 404, body: "{}"))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .notFound)
}

@Test @MainActor func returnsUnavailableOnMalformedJSON() async {
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 200, body: "not json"))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .unavailable)
}

@Test @MainActor func returnsUnavailableOnServerFailure() async {
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(statusCode: 503, body: "{}"))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .unavailable)
}

@Test @MainActor func returnsUnavailableOnNetworkFailure() async {
    let provider = LRCLibProvider(httpClient: FakeHTTPClient(result: .failure))
    let result = await provider.lyrics(for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil))
    #expect(result == .unavailable)
}

@Test @MainActor func searchFallbackFindsSyncedLyricsWhenGetReturnsPlainOnly() async {
    let getBody = #"{"syncedLyrics":null,"plainLyrics":"Just words"}"#
    let searchBody = """
    [
        {"artistName":"A","trackName":"T","syncedLyrics":null,"plainLyrics":"Just words","duration":300},
        {"artistName":"A","trackName":"T","syncedLyrics":"[00:02.00]Hi\\n","plainLyrics":"Hi","duration":248}
    ]
    """
    let client = FakeHTTPClient { request in
        if request.url!.path.contains("/search") {
            return .response(statusCode: 200, body: searchBody)
        }
        return .response(statusCode: 200, body: getBody)
    }
    let provider = LRCLibProvider(httpClient: client)
    let result = await provider.lyrics(
        for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: 248)
    )
    guard case .synced(let lines) = result else {
        Issue.record("expected synced result from search fallback")
        return
    }
    #expect(lines == [LyricLine(timestamp: 2.0, text: "Hi")])
}

@Test @MainActor func searchFallbackKeepsPlainWhenNoSyncedFoundInSearch() async {
    let getBody = #"{"syncedLyrics":null,"plainLyrics":"Just words"}"#
    let searchBody = """
    [
        {"syncedLyrics":null,"plainLyrics":"Just words","duration":300},
        {"syncedLyrics":null,"plainLyrics":"Other words","duration":248}
    ]
    """
    let client = FakeHTTPClient { request in
        if request.url!.path.contains("/search") {
            return .response(statusCode: 200, body: searchBody)
        }
        return .response(statusCode: 200, body: getBody)
    }
    let provider = LRCLibProvider(httpClient: client)
    let result = await provider.lyrics(
        for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: 248)
    )
    #expect(result == .plain("Just words"))
}

@Test @MainActor func doesNotSearchWhenGetReturnsSyncedLyrics() async {
    let getBody = #"{"syncedLyrics":"[00:01.00]Hello\n","plainLyrics":"Hello"}"#
    let client = FakeHTTPClient { request in
        if request.url!.path.contains("/search") {
            return .response(statusCode: 500, body: "should not be called")
        }
        return .response(statusCode: 200, body: getBody)
    }
    let provider = LRCLibProvider(httpClient: client)
    let result = await provider.lyrics(
        for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil)
    )
    guard case .synced(let lines) = result else {
        Issue.record("expected synced result without a search call")
        return
    }
    #expect(lines == [LyricLine(timestamp: 1.0, text: "Hello")])
}

@Test @MainActor func searchFallbackFindsSyncedLyricsWhenGetReturns404() async {
    let searchBody = """
    [
        {"syncedLyrics":"[00:03.00]Yo\\n","plainLyrics":"Yo","duration":248}
    ]
    """
    let client = FakeHTTPClient { request in
        if request.url!.path.contains("/search") {
            return .response(statusCode: 200, body: searchBody)
        }
        return .response(statusCode: 404, body: "{}")
    }
    let provider = LRCLibProvider(httpClient: client)
    let result = await provider.lyrics(
        for: TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: 248)
    )
    guard case .synced(let lines) = result else {
        Issue.record("expected synced result from search fallback after 404")
        return
    }
    #expect(lines == [LyricLine(timestamp: 3.0, text: "Yo")])
}

@Test @MainActor func searchFallbackIgnoresSyncedCandidateWithUnrelatedArtist() async {
    // Regression: a broader q= search can surface synced lyrics for a
    // completely different song. Without an artist check we'd wrongly show
    // someone else's lyrics, so an unrelated-artist match must be rejected
    // and the original plain result kept.
    let getBody = #"{"syncedLyrics":null,"plainLyrics":"Just words"}"#
    let searchBody = """
    [
        {"artistName":"Some Other Band","trackName":"Unrelated Song","syncedLyrics":"[00:01.00]Nope\\n","plainLyrics":"Nope","duration":248}
    ]
    """
    let client = FakeHTTPClient { request in
        if request.url!.path.contains("/search") {
            return .response(statusCode: 200, body: searchBody)
        }
        return .response(statusCode: 200, body: getBody)
    }
    let provider = LRCLibProvider(httpClient: client)
    let result = await provider.lyrics(
        for: TrackSignature(title: "Ran To Atlanta", artist: "Drake, Future & Molly Santana", album: nil, durationSeconds: 248)
    )
    #expect(result == .plain("Just words"))
}

@Test @MainActor func searchFallbackFindsSyncedLyricsDespiteMessyTrackNameMetadata() async {
    // Regression for the real "Ran To Atlanta" case: LRCLIB's own synced
    // submission had the artist name jammed into the track title
    // ("Drake, Future, Molly Santana - Ran To Atlanta") rather than a clean
    // trackName, and a decoy from an unrelated artist ranks first. The
    // fallback must still pick the artist-matching synced entry.
    let getBody = #"{"syncedLyrics":null,"plainLyrics":"Just words"}"#
    let searchBody = """
    [
        {"artistName":"Some Other Band","trackName":"Unrelated Song","syncedLyrics":"[00:01.00]Nope\\n","plainLyrics":"Nope","duration":248},
        {"artistName":"Drake","trackName":"Drake, Future, Molly Santana - Ran To Atlanta","syncedLyrics":"[00:03.00]Yo\\n","plainLyrics":"Yo","duration":248}
    ]
    """
    let client = FakeHTTPClient { request in
        if request.url!.path.contains("/search") {
            return .response(statusCode: 200, body: searchBody)
        }
        return .response(statusCode: 200, body: getBody)
    }
    let provider = LRCLibProvider(httpClient: client)
    let result = await provider.lyrics(
        for: TrackSignature(title: "Ran To Atlanta", artist: "Drake, Future & Molly Santana", album: nil, durationSeconds: 248)
    )
    guard case .synced(let lines) = result else {
        Issue.record("expected synced result matched via track-title-embedded artist")
        return
    }
    #expect(lines == [LyricLine(timestamp: 3.0, text: "Yo")])
}
