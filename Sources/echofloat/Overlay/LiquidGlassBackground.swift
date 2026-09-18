import SwiftUI

struct LiquidGlassBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundColors.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(theme.blurIntensity)
            if theme.motif == .neonGrid {
                NeonGridMotif(color: Color(hex: theme.accentColorHex))
            }
        }
    }
}
