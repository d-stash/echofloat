import SwiftUI

struct Theme: Identifiable, Equatable {
    enum Motif: Equatable {
        case none
        /// Neon Arcade: faint perspective grid confined to the lower half.
        case neonGrid
        /// Sunset Vaporwave: painted sky gradient + mountain silhouette + a
        /// glowing sun disc.
        case mountains
    }

    /// Decorative background animation each theme drives; kept as an enum so future
    /// themes can each plug in their own without touching unrelated themes.
    enum AnimationStyle: Equatable {
        case none
        /// Neon Arcade: sine-wave pulse under the lyrics, speeds up while playing.
        case sineWavePulse
    }

    enum AlbumArtShape: Equatable {
        case roundedSquare
        case circle
    }

    enum AccessoryIcon: Equatable {
        case none
        case heart
        case ellipsis
        case equalizer
    }

    let id: String
    let name: String
    let backgroundColors: [String]
    let accentColorHex: String
    let blurIntensity: Double
    let motif: Motif
    let animationStyle: AnimationStyle
    /// Whether this theme's surface reads as light (e.g. cream/paper) or dark, so
    /// text/chrome can stay legible without every theme repeating the same
    /// handful of color decisions.
    let isLight: Bool
    /// Monospaced/pixel-style font vs. the system default (used by Retro Terminal).
    let usesMonospacedFont: Bool
    let cornerRadius: CGFloat
    /// Border color for themes with a drawn outline (Neon Arcade's glow border,
    /// Retro Terminal's pixel border). nil means no visible border stroke.
    let borderColorHex: String?
    let borderGlows: Bool
    let albumArtShape: AlbumArtShape
    let accessoryIcon: AccessoryIcon

    var textColor: Color { isLight ? Color.black.opacity(0.82) : .white }
    var secondaryTextColor: Color { isLight ? Color.black.opacity(0.5) : .white.opacity(0.55) }
    var chromeOverlayColor: Color { isLight ? Color.white.opacity(0.3) : Color.black.opacity(0.15) }
    var dividerColor: Color { isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.12) }
    var fontDesign: Font.Design { usesMonospacedFont ? .monospaced : .default }

    static let neonArcade = Theme(
        id: "neon-arcade",
        name: "Neon Arcade",
        backgroundColors: ["#12061F", "#1B0A33"],
        accentColorHex: "#FF3EC9",
        blurIntensity: 0.95,
        motif: .neonGrid,
        animationStyle: .sineWavePulse,
        isLight: false,
        usesMonospacedFont: false,
        cornerRadius: 16,
        borderColorHex: "#FF3EC9",
        borderGlows: true,
        albumArtShape: .roundedSquare,
        accessoryIcon: .equalizer
    )

    static let retroTerminal = Theme(
        id: "retro-terminal",
        name: "Retro Terminal",
        backgroundColors: ["#050805", "#050805"],
        accentColorHex: "#39FF6A",
        blurIntensity: 1.0,
        motif: .none,
        animationStyle: .none,
        isLight: false,
        usesMonospacedFont: true,
        cornerRadius: 4,
        borderColorHex: "#39FF6A",
        borderGlows: false,
        albumArtShape: .roundedSquare,
        accessoryIcon: .equalizer
    )

    static let midnightAurora = Theme(
        id: "midnight-aurora",
        name: "Midnight Aurora",
        backgroundColors: ["#161A2E", "#1E2340"],
        accentColorHex: "#8FA3FF",
        blurIntensity: 1.0,
        motif: .none,
        animationStyle: .none,
        isLight: false,
        usesMonospacedFont: false,
        cornerRadius: 20,
        borderColorHex: nil,
        borderGlows: false,
        albumArtShape: .roundedSquare,
        accessoryIcon: .ellipsis
    )

    static let sunsetVaporwave = Theme(
        id: "sunset-vaporwave",
        name: "Sunset Vaporwave",
        backgroundColors: ["#3A2E52", "#4A3763", "#7A4A55"],
        accentColorHex: "#FFB37A",
        blurIntensity: 1.0,
        motif: .mountains,
        animationStyle: .none,
        isLight: false,
        usesMonospacedFont: false,
        cornerRadius: 18,
        borderColorHex: nil,
        borderGlows: false,
        albumArtShape: .roundedSquare,
        accessoryIcon: .equalizer
    )

    static let vinylWarmth = Theme(
        id: "vinyl-warmth",
        name: "Vinyl Warmth",
        backgroundColors: ["#F2ECE1", "#EDE4D3"],
        accentColorHex: "#B08D57",
        blurIntensity: 1.0,
        motif: .none,
        animationStyle: .none,
        isLight: true,
        usesMonospacedFont: false,
        cornerRadius: 20,
        borderColorHex: nil,
        borderGlows: false,
        albumArtShape: .circle,
        accessoryIcon: .equalizer
    )

    static let builtIn: [Theme] = [.neonArcade, .retroTerminal, .midnightAurora, .sunsetVaporwave, .vinylWarmth]
}
