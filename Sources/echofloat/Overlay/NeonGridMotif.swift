import SwiftUI

/// Retro-arcade grid motif: both axes, brighter near the bottom (perspective/horizon
/// feel), plus a soft glow so it actually reads as "neon" rather than faint gridlines.
struct NeonGridMotif: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacingX: CGFloat = 22
            let spacingY: CGFloat = 16

            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: 1)
                x += spacingX
            }

            var y: CGFloat = 0
            while y < size.height {
                // Lines get brighter toward the bottom to fake an arcade-grid horizon.
                let t = y / max(size.height, 1)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color.opacity(0.15 + 0.3 * t)), lineWidth: 1)
                y += spacingY
            }
        }
        .blur(radius: 0.4)
        .shadow(color: color.opacity(0.6), radius: 6)
        .allowsHitTesting(false)
    }
}
