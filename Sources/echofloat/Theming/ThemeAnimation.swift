import Foundation

enum ThemeAnimation {
    static let shootingStarPeriod: TimeInterval = 6
    static let sunsetTimeLapsePeriod: TimeInterval = 20
    static let sunsetBirdFlightDuration = 0.5
    static let neonClearCenterFraction = 0.6

    static func wingLift(at time: TimeInterval) -> Double {
        sin(time * .pi * 4)
    }

    static func neonCityScale(phase: Double) -> Double {
        1 + 0.0125 * (1 - cos(phase * .pi * 2))
    }

    static func phase(
        at time: TimeInterval,
        period: TimeInterval,
        isPlaying: Bool,
        reduceMotion: Bool
    ) -> Double {
        guard isPlaying, !reduceMotion, period > 0 else { return 0 }
        return time.truncatingRemainder(dividingBy: period) / period
    }
}
