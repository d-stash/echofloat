import SwiftUI

struct Theme: Identifiable, Equatable {
    enum Motif: Equatable {
        case none
        case neonGrid
    }

    /// Decorative background animation each theme drives; kept as an enum so future
    /// themes (backlog: Midnight Aurora, Retro Terminal, Sunset Vaporwave) can each
    /// plug in their own without touching unrelated themes.
    enum AnimationStyle: Equatable {
        case none
        /// Liquid Glass: slow diagonal specular highlight sweeping across the panel.
        case glassSheen
        /// Neon Arcade: sine-wave pulse under the lyrics, speeds up while playing.
        case sineWavePulse
    }

    let id: String
    let name: String
    let backgroundColors: [String]
    let accentColorHex: String
    let blurIntensity: Double
    let motif: Motif
    let animationStyle: AnimationStyle
    /// Whether this theme's surface reads as light (e.g. frosted white glass) or
    /// dark, so text/chrome can stay legible without every theme repeating the
    /// same handful of color decisions.
    let isLight: Bool

    var textColor: Color { isLight ? Color.black.opacity(0.82) : .white }
    var secondaryTextColor: Color { isLight ? Color.black.opacity(0.5) : .white.opacity(0.55) }
    var chromeOverlayColor: Color { isLight ? Color.white.opacity(0.3) : Color.black.opacity(0.15) }
    var dividerColor: Color { isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.12) }

    static let auroraGlass = Theme(
        id: "aurora-glass",
        name: "Liquid Glass",
        backgroundColors: ["#FFFFFF", "#DCE8F5"],
        accentColorHex: "#0A84FF",
        blurIntensity: 0.05,
        motif: .none,
        animationStyle: .glassSheen,
        isLight: true
    )

    static let neonArcade = Theme(
        id: "neon-arcade",
        name: "Neon Arcade",
        backgroundColors: ["#0D0221", "#190A33"],
        accentColorHex: "#FF2E92",
        blurIntensity: 0.8,
        motif: .neonGrid,
        animationStyle: .none,
        isLight: false
    )

    static let builtIn: [Theme] = [.auroraGlass, .neonArcade]
}
