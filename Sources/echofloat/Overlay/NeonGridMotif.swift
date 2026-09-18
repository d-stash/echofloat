import SwiftUI

struct NeonGridMotif: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color.opacity(0.15)), lineWidth: 1)
                x += spacing
            }
        }
    }
}
