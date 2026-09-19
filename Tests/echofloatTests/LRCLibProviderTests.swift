import Foundation
import Testing
@testable import echofloat

private struct FakeHTTPClient: HTTPClient {
    enum Result {
        case response(statusCode: Int, body: String)
        case failure
    }

    let result: Result

    init(statusCode: Int, body: String) {
        result = .response(statusCode: statusCode, body: body)
    }

    init(result: Result) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard case .response(let statusCode, let body) = result else {
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
