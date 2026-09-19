import SwiftUI

/// Perspective road grid whose horizontal rows accelerate toward the viewer.
struct NeonGridMotif: View {
    let color: Color
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let roadPhase = ThemeAnimation.phase(
                at: time,
                period: 1.4,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )
            let cityPhase = ThemeAnimation.phase(
                at: time,
                period: 18,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                let horizonY = size.height * 0.52
                let centerX = size.width / 2

                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: 6))
                    glow.fill(
                        Path(CGRect(x: 0, y: horizonY - 2, width: size.width, height: 4)),
                        with: .linearGradient(
                            Gradient(colors: [
                                color.opacity(0.04),
                                color.opacity(0.2),
                                color.opacity(0.04)
                            ]),
                            startPoint: CGPoint(x: 0, y: horizonY),
                            endPoint: CGPoint(x: size.width, y: horizonY)
                        )
                    )
                }

                let cityScale = CGFloat(ThemeAnimation.neonCityScale(phase: cityPhase))
                let sideFraction = (1 - ThemeAnimation.neonClearCenterFraction) / 2
                let sideWidth = size.width * sideFraction
                let heights: [CGFloat] = [0.2, 0.34, 0.27, 0.46, 0.31, 0.4]
                let buildingWidth = sideWidth / CGFloat(heights.count) * cityScale

                for side in 0..<2 {
                    for (index, heightFraction) in heights.enumerated() {
                        let x: CGFloat
                        if side == 0 {
                            x = CGFloat(index) * buildingWidth
                        } else {
                            x = size.width - CGFloat(index + 1) * buildingWidth
                        }
                        let height = size.height * heightFraction * cityScale
                        let rect = CGRect(
                            x: x,
                            y: horizonY - height,
                            width: buildingWidth + 0.5,
                            height: height
                        )
                        context.fill(Path(rect), with: .color(.black.opacity(0.76)))
                        context.stroke(
                            Path(rect),
                            with: .color(color.opacity(0.2)),
                            lineWidth: 0.6
                        )

                        let twinkle = 0.15 + 0.3 * abs(
                            sin(cityPhase * .pi * 2 + Double(index + side * heights.count))
                        )
                        let window = CGRect(
                            x: rect.midX - 1,
                            y: rect.minY + height * 0.32,
                            width: 2,
                            height: 2
                        )
                        context.fill(Path(window), with: .color(color.opacity(twinkle)))
                    }
                }

                for lane in -8...8 {
                    let bottomX = centerX + CGFloat(lane) * size.width / 7
                    var path = Path()
                    path.move(to: CGPoint(x: centerX, y: horizonY))
                    path.addLine(to: CGPoint(x: bottomX, y: size.height))
                    context.stroke(path, with: .color(color.opacity(0.13)), lineWidth: 1)
                }

                for row in 0..<10 {
                    let progress = (Double(row) + roadPhase) / 10
                    let eased = progress * progress
                    let y = horizonY + CGFloat(eased) * (size.height - horizonY)
                    let opacity = 0.04 + eased * 0.18
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 1)
                }

                let horizonPulse = 0.18 + 0.08 * abs(sin(roadPhase * .pi * 2))
                let horizon = CGRect(x: 0, y: horizonY - 1, width: size.width, height: 2)
                context.fill(Path(horizon), with: .color(color.opacity(horizonPulse)))
            }
            .allowsHitTesting(false)
        }
    }
}
