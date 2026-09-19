import Foundation

@main
struct ThemeAnimationChecks {
    static func main() {
        precondition(Theme.neonArcade.animationStyle == .neonDrive)
        precondition(Theme.retroTerminal.animationStyle == .retroCRT)
        precondition(Theme.midnightAurora.animationStyle == .midnightSky)
        precondition(Theme.sunsetVaporwave.animationStyle == .sunsetParallax)
        precondition(Theme.vinylWarmth.animationStyle == .vinylSpin)
        precondition(ThemeAnimation.shootingStarPeriod == 6)
        precondition(ThemeAnimation.sunsetTimeLapsePeriod == 20)
        precondition(ThemeAnimation.sunsetBirdFlightDuration == 0.5)
        precondition(abs(ThemeAnimation.wingLift(at: 0.125) - 1) < 0.0001)
        precondition(abs(ThemeAnimation.neonCityScale(phase: 0) - 1) < 0.0001)
        precondition(abs(ThemeAnimation.neonCityScale(phase: 0.5) - 1.025) < 0.0001)
        precondition(ThemeAnimation.neonClearCenterFraction == 0.6)

        let activePhase = ThemeAnimation.phase(
            at: 9,
            period: 4,
            isPlaying: true,
            reduceMotion: false
        )
        precondition(abs(activePhase - 0.25) < 0.0001)
        precondition(
            ThemeAnimation.phase(
                at: 9,
                period: 4,
                isPlaying: false,
                reduceMotion: false
            ) == 0
        )
        precondition(
            ThemeAnimation.phase(
                at: 9,
                period: 4,
                isPlaying: true,
                reduceMotion: true
            ) == 0
        )
    }
}
