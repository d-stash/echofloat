import Foundation

@MainActor
struct LRCLibProvider: LyricsProvider {
    private let httpClient: HTTPClient
    private let baseURL: URL

    init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
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
        guard let url = requestURL(for: track) else { return .unavailable }

        do {
            let (data, response) = try await httpClient.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse else {
                return .unavailable
            }
            if http.statusCode == 404 {
                return .notFound
            }
            guard http.statusCode == 200 else { return .unavailable }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            if let synced = decoded.syncedLyrics, !synced.isEmpty {
                return .synced(LRCParser.parse(synced))
            }
            if let plain = decoded.plainLyrics, !plain.isEmpty {
                return .plain(plain)
            }
            return .notFound
        } catch {
            return .unavailable
        }
    }

    private func requestURL(for track: TrackSignature) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        var items = [
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "track_name", value: track.title),
        ]
        if let album = track.album {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if let duration = track.durationSeconds {
            items.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        components.queryItems = items
        return components.url
    }
}
