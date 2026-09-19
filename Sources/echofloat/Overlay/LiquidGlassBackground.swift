import SwiftUI

struct LiquidGlassBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            // .behindWindow blurs the actual desktop/apps behind the panel (true
            // "liquid glass" see-through). .withinWindow only blurs content inside
            // this same transparent window, i.e. nothing — which is why it used
            // to look like a flat opaque gradient instead of translucent glass.
            // .hudWindow always forces Apple's dark HUD tint (even in light
            // appearance), which is why the glass theme read as flat opaque gray;
            // .popover stays vibrant/transparent and follows system appearance.
            VisualEffectBlur(
                material: theme.isLight ? .popover : .hudWindow,
                blendingMode: .behindWindow
            )

            LinearGradient(
                colors: theme.backgroundColors.map { Color(hex: $0).opacity(theme.blurIntensity) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if theme.motif == .neonGrid {
                NeonGridMotif(color: Color(hex: theme.accentColorHex))
            }

            if theme.animationStyle == .glassSheen {
                GlassSheenOverlay()
            }

            // Rim light: bright top edge fading to near-invisible at the bottom, as
            // if lit from above — the visual cue that sells "glass" over a flat tint.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(theme.isLight ? 0.9 : 0.5), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // Soft inner shadow along the bottom edge for a sense of glass thickness.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(theme.isLight ? 0.12 : 0.25), lineWidth: 6)
                .blur(radius: 4)
                .mask(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

/// Slow diagonal specular highlight that sweeps across the panel every ~8s, like
/// light catching a curved glass surface. Kept extremely subtle/low-opacity so it
/// reads as ambient shimmer, not a loud effect.
private struct GlassSheenOverlay: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let period: Double = 8
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            Canvas { context, size in
                let sweepWidth = size.width * 0.5
                let x = -sweepWidth + CGFloat(t) * (size.width + sweepWidth * 2)
                let rect = CGRect(x: x, y: -size.height * 0.5, width: sweepWidth, height: size.height * 2)
                let gradient = Gradient(stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.18), location: 0.5),
                    .init(color: .white.opacity(0), location: 1)
                ])
                context.opacity = 1
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: rect.minX, y: 0),
                        endPoint: CGPoint(x: rect.maxX, y: 0)
                    )
                )
            }
            .rotationEffect(.degrees(-20))
            .allowsHitTesting(false)
        }
    }
}
