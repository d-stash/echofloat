import SwiftUI

/// Subtle perspective grid confined to the lower half of the panel, fading out
/// toward the top — matches the reference design's faint floor grid rather than
/// the earlier version's full-panel, overly dense/bright grid.
struct NeonGridMotif: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let horizonY = size.height * 0.45
            let spacingX: CGFloat = 26

            var x: CGFloat = -size.width
            while x < size.width * 2 {
                var path = Path()
                path.move(to: CGPoint(x: size.width / 2, y: horizonY))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color.opacity(0.12)), lineWidth: 1)
                x += spacingX
            }

            let rowSpacing: CGFloat = 14
            var y = horizonY
            while y < size.height {
                let t = (y - horizonY) / max(size.height - horizonY, 1)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color.opacity(0.05 + 0.12 * t)), lineWidth: 1)
                y += rowSpacing
            }
        }
        .allowsHitTesting(false)
    }
}
