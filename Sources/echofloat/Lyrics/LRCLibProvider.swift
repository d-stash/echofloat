import Foundation

@MainActor
struct LRCLibProvider: LyricsProvider {
    private let httpClient: HTTPClient
    private let baseURL: URL
    private let searchURL: URL

    init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://lrclib.net/api/get")!,
        searchURL: URL = URL(string: "https://lrclib.net/api/search")!
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.searchURL = searchURL
    }

    private struct Response: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    private struct SearchResult: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
        let duration: Double?
    }

    func lyrics(for track: TrackSignature) async -> LyricsResult {
        guard let url = requestURL(for: track) else { return .unavailable }

        do {
            let (data, response) = try await httpClient.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse else {
                return .unavailable
            }
            if http.statusCode == 404 {
                if let synced = await syncedLyricsFromSearch(for: track) {
                    return .synced(synced)
                }
                return .notFound
            }
            guard http.statusCode == 200 else { return .unavailable }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            if let synced = decoded.syncedLyrics, !synced.isEmpty {
                return .synced(LRCParser.parse(synced))
            }
            // The direct match lacks synced lyrics; search LRCLIB's broader
            // catalog for an alternate release of the same track that has them
            // before settling for plain (unsynced) text.
            if let synced = await syncedLyricsFromSearch(for: track) {
                return .synced(synced)
            }
            if let plain = decoded.plainLyrics, !plain.isEmpty {
                return .plain(plain)
            }
            return .notFound
        } catch {
            return .unavailable
        }
    }

    /// Searches LRCLIB for an alternate entry of `track` that has synced lyrics.
    /// Returns `nil` if the search fails, decodes nothing usable, or no
    /// candidate has synced lyrics.
    private func syncedLyricsFromSearch(for track: TrackSignature) async -> [LyricLine]? {
        guard let url = searchRequestURL(for: track) else { return nil }
        do {
            let (data, response) = try await httpClient.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let results = try JSONDecoder().decode([SearchResult].self, from: data)
            let candidates = results.compactMap { result -> (String, Double)? in
                guard let synced = result.syncedLyrics, !synced.isEmpty else { return nil }
                return (synced, result.duration ?? .infinity)
            }
            guard !candidates.isEmpty else { return nil }
            let targetDuration = track.durationSeconds.map(Double.init) ?? .infinity
            let best = candidates.min { lhs, rhs in
                abs(lhs.1 - targetDuration) < abs(rhs.1 - targetDuration)
            }
            guard let best else { return nil }
            return LRCParser.parse(best.0)
        } catch {
            return nil
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

    private func searchRequestURL(for track: TrackSignature) -> URL? {
        guard var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "track_name", value: track.title),
        ]
        return components.url
    }
}
