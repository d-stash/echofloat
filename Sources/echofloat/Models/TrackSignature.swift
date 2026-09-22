import Foundation

struct TrackSignature: Hashable, Codable {
    let title: String
    let artist: String
    let album: String?
    let durationSeconds: Int?

    var cacheKey: String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedArtist)::\(normalizedTitle)"
    }
}
