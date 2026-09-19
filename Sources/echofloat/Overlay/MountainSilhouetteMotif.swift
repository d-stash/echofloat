import SwiftUI

/// Painted dusk-sky backdrop: a glowing sun disc low on the horizon plus two
/// layered mountain silhouettes, matching the reference design's landscape mood.
struct MountainSilhouetteMotif: View {
    let sunColor: Color
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = ThemeAnimation.phase(
                at: time,
                period: ThemeAnimation.sunsetTimeLapsePeriod,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color.purple.opacity(phase * 0.2))
                )

                let sunCenter = CGPoint(
                    x: size.width * (0.72 + phase * 0.12),
                    y: size.height * (0.2 + phase * 0.54)
                )
                let pulse = 0.94 + 0.06 * sin(phase * .pi * 4)
                let sunRadius = size.height * 0.22 * pulse
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

                let birdStart = 0.1
                let birdEnd = birdStart + ThemeAnimation.sunsetBirdFlightDuration
                if phase > birdStart, phase < birdEnd {
                    let birdProgress = (phase - birdStart) / ThemeAnimation.sunsetBirdFlightDuration
                    let birdX = size.width * (0.2 + birdProgress * 0.55)
                    let birdY = size.height * (0.26 - sin(birdProgress * .pi) * 0.08)
                    for offset in [CGFloat.zero, 14] {
                        let flap = CGFloat(ThemeAnimation.wingLift(at: time + Double(offset) * 0.01))
                        var bird = Path()
                        bird.move(to: CGPoint(x: birdX + offset, y: birdY - flap * 3))
                        bird.addLine(to: CGPoint(x: birdX + offset + 4, y: birdY))
                        bird.addLine(to: CGPoint(x: birdX + offset + 8, y: birdY - flap * 3))
                        context.stroke(
                            bird,
                            with: .color(Color.black.opacity(0.55)),
                            lineWidth: 1
                        )
                    }
                }

                func ridge(baseline: CGFloat, amplitude: CGFloat, offset: CGFloat, color: Color) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: baseline))
                    let step: CGFloat = 8
                    var x: CGFloat = 0
                    while x <= size.width {
                        let wave = ((x + offset) / size.width) * .pi * 1.6
                        path.addLine(to: CGPoint(x: x, y: baseline - amplitude * sin(wave)))
                        x += step
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(color))
                }

                ridge(
                    baseline: size.height * 0.78,
                    amplitude: size.height * 0.12,
                    offset: size.width * 0.08,
                    color: .black.opacity(0.28)
                )
                ridge(
                    baseline: size.height * 0.88,
                    amplitude: size.height * 0.08,
                    offset: size.width * 0.3,
                    color: .black.opacity(0.45)
                )
            }
            .allowsHitTesting(false)
        }
    }
}
