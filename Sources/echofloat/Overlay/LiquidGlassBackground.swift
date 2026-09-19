import SwiftUI

struct LiquidGlassBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            // .behindWindow blurs the actual desktop/apps behind the panel (true
            // "liquid glass" see-through). .withinWindow only blurs content inside
            // this same transparent window, i.e. nothing — which is why it used
            // to look like a flat opaque gradient instead of translucent glass.
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: theme.backgroundColors.map { Color(hex: $0).opacity(theme.blurIntensity) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if theme.motif == .neonGrid {
                NeonGridMotif(color: Color(hex: theme.accentColorHex))
            }

            // Thin edge highlight + inner glow, the hallmark of macOS "liquid glass"
            // material — otherwise borderless transparent panels look like they
            // have no surface at all.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }
}
