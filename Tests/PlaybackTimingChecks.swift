import Foundation

@main
struct PlaybackTimingChecks {
    static func main() {
        let track = TrackSignature(
            title: "Track",
            artist: "Artist",
            album: nil,
            durationSeconds: 12
        )
        let capturedAt = Date(timeIntervalSinceReferenceDate: 100)

        let playing = NowPlayingState(
            track: track,
            sourceAppName: "Test",
            status: .playing,
            elapsedSeconds: 10,
            capturedAt: capturedAt
        )
        precondition(
            abs(
                PlaybackClock.estimatedElapsed(
                    for: playing,
                    at: Date(timeIntervalSinceReferenceDate: 100.35)
                ) - 10.35
            ) < 0.0001
        )

        let paused = NowPlayingState(
            track: track,
            sourceAppName: "Test",
            status: .paused,
            elapsedSeconds: 10,
            capturedAt: capturedAt
        )
        precondition(
            PlaybackClock.estimatedElapsed(
                for: paused,
                at: Date(timeIntervalSinceReferenceDate: 105)
            ) == 10
        )

        precondition(
            PlaybackClock.estimatedElapsed(
                for: playing,
                at: Date(timeIntervalSinceReferenceDate: 105)
            ) == 12
        )
    }
}
