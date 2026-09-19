import SwiftUI

/// Painted dusk-sky backdrop: a glowing sun disc low on the horizon plus two
/// layered mountain silhouettes, matching the reference design's landscape mood.
struct MountainSilhouetteMotif: View {
    let sunColor: Color

    var body: some View {
        Canvas { context, size in
            let sunCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.32)
            let sunRadius = size.height * 0.22
            context.drawLayer { ctx in
                ctx.addFilter(.blur(radius: 6))
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius,
                        width: sunRadius * 2, height: sunRadius * 2
                    )),
                    with: .color(sunColor.opacity(0.9))
                )
            }

            func ridge(baseline: CGFloat, amplitude: CGFloat, phase: CGFloat, color: Color) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: baseline))
                let step: CGFloat = 8
                var x: CGFloat = 0
                while x <= size.width {
                    let y = baseline - amplitude * sin((x / size.width) * .pi * 1.6 + phase)
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += step
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }

            ridge(baseline: size.height * 0.78, amplitude: size.height * 0.12, phase: 0.6, color: .black.opacity(0.28))
            ridge(baseline: size.height * 0.88, amplitude: size.height * 0.08, phase: 2.1, color: .black.opacity(0.45))
        }
        .allowsHitTesting(false)
    }
}
