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
