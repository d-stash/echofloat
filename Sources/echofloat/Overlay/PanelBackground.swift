import SwiftUI

/// Shared background renderer for every theme: a gradient fill plus each theme's
/// own motif (Neon Arcade's grid, Sunset Vaporwave's mountains), and a themed
/// border (plain, pixel-outline, or glow) drawn on top. Liquid Glass (real
/// behind-window blur via NSVisualEffectView) was removed — macOS requires
/// Screen Recording permission for true .behindWindow transparency, and even
/// after granting it the panel still rendered as flat opaque gray, so themes now
/// use plain gradients/solid colors matched to user-supplied design references
/// instead of chasing that effect.
struct PanelBackground: View {
    let theme: Theme
    let isPlaying: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundColors.map { Color(hex: $0) },
                startPoint: .top,
                endPoint: .bottom
            )

            switch theme.animationStyle {
            case .neonDrive:
                NeonGridMotif(
                    color: Color(hex: theme.accentColorHex),
                    isPlaying: isPlaying
                )
            case .retroCRT:
                RetroCRTMotif(
                    color: Color(hex: theme.accentColorHex),
                    isPlaying: isPlaying
                )
            case .midnightSky:
                MidnightSkyMotif(
                    color: Color(hex: theme.accentColorHex),
                    isPlaying: isPlaying
                )
            case .sunsetParallax:
                MountainSilhouetteMotif(
                    sunColor: Color(hex: theme.accentColorHex),
                    isPlaying: isPlaying
                )
            case .vinylSpin:
                PaperGrainMotif(isPlaying: isPlaying)
            }

            if let borderHex = theme.borderColorHex {
                let border = Color(hex: borderHex)
                if theme.animationStyle == .retroCRT {
                    PixelBorder(color: border)
                } else {
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: theme.borderGlows ? 1.5 : 2)
                        .shadow(color: theme.borderGlows ? border.opacity(0.8) : .clear, radius: 6)
                        .shadow(color: theme.borderGlows ? border.opacity(0.5) : .clear, radius: 14)
                }
            }
        }
    }
}
