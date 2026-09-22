import Foundation

@MainActor
protocol LyricsProvider {
    func lyrics(for track: TrackSignature) async -> LyricsResult
}

@MainActor
protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

@MainActor
struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request, delegate: nil)
    }
}
