import Foundation
import Testing
@testable import echofloat

private func playbackState(
    elapsed: Double,
    duration: Int? = nil,
    status: NowPlayingState.PlaybackStatus = .playing,
    capturedAt: Date
) -> NowPlayingState {
    NowPlayingState(
        track: TrackSignature(
            title: "Song",
            artist: "Artist",
            album: nil,
            durationSeconds: duration
        ),
        sourceAppName: "Test",
        status: status,
        elapsedSeconds: elapsed,
        capturedAt: capturedAt
    )
}

@Test func advancesElapsedTimeLocallyWhilePlaying() {
    let capturedAt = Date(timeIntervalSince1970: 100)
    let state = playbackState(elapsed: 12, capturedAt: capturedAt)

    #expect(PlaybackClock.estimatedElapsed(
        for: state,
        at: capturedAt.addingTimeInterval(0.75)
    ) == 12.75)
}

@Test func keepsElapsedTimeFixedWhilePaused() {
    let capturedAt = Date(timeIntervalSince1970: 100)
    let state = playbackState(elapsed: 12, status: .paused, capturedAt: capturedAt)

    #expect(PlaybackClock.estimatedElapsed(
        for: state,
        at: capturedAt.addingTimeInterval(5)
    ) == 12)
}

@Test func clampsEstimatedElapsedTimeToTrackDuration() {
    let capturedAt = Date(timeIntervalSince1970: 100)
    let state = playbackState(elapsed: 29.5, duration: 30, capturedAt: capturedAt)

    #expect(PlaybackClock.estimatedElapsed(
        for: state,
        at: capturedAt.addingTimeInterval(2)
    ) == 30)
}

@Test func ignoresDatesBeforeStateCapture() {
    let capturedAt = Date(timeIntervalSince1970: 100)
    let state = playbackState(elapsed: 12, capturedAt: capturedAt)

    #expect(PlaybackClock.estimatedElapsed(
        for: state,
        at: capturedAt.addingTimeInterval(-1)
    ) == 12)
}
