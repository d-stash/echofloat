import Foundation

enum PlaybackClock {
    static func estimatedElapsed(for state: NowPlayingState, at date: Date = Date()) -> Double {
        guard state.status == .playing else { return state.elapsedSeconds }
        let elapsed = state.elapsedSeconds + max(0, date.timeIntervalSince(state.capturedAt))
        guard let duration = state.track.durationSeconds else { return elapsed }
        return min(elapsed, Double(duration))
    }
}
