import Foundation

struct NowPlayingState: Equatable {
    enum PlaybackStatus: Equatable {
        case playing
        case paused
        case stopped
    }

    let track: TrackSignature
    let sourceAppName: String
    let status: PlaybackStatus
    let elapsedSeconds: Double
    let capturedAt: Date
}
