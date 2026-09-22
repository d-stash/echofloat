import SwiftUI

struct MidnightSkyMotif: View {
    let color: Color
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isPlaying || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let twinklePhase = ThemeAnimation.phase(
                at: time,
                period: 4,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )
            let shootingPhase = ThemeAnimation.phase(
                at: time,
                period: ThemeAnimation.shootingStarPeriod,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                var ribbon = Path()
                ribbon.move(to: CGPoint(x: 0, y: size.height * 0.6))
                let step: CGFloat = 8
                var ribbonX: CGFloat = 0
                while ribbonX <= size.width {
                    let normalizedX = Double(ribbonX / max(size.width, 1))
                    let angle = normalizedX * Double.pi * 2 + twinklePhase * Double.pi * 2
                    let wave = CGFloat(sin(angle))
                    ribbon.addLine(to: CGPoint(
                        x: ribbonX,
                        y: size.height * 0.6 + wave * size.height * 0.08
                    ))
                    ribbonX += step
                }
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 8))
                    layer.stroke(
                        ribbon,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.cyan.opacity(0.05),
                                color.opacity(0.18),
                                Color.purple.opacity(0.08)
                            ]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        lineWidth: 10
                    )
                }

                for index in 0..<26 {
                    let x = CGFloat((index * 47) % 101) / 101 * size.width
                    let y = CGFloat((index * 29) % 67) / 67 * size.height
                    let pulse = 0.35 + 0.65 * abs(sin(twinklePhase * .pi * 2 + Double(index)))
                    let radius: CGFloat = index.isMultiple(of: 7) ? 1.4 : 0.8
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(.white.opacity(0.18 + pulse * 0.42))
                    )
                }

                let moonRadius = min(size.height * 0.24, 24)
                let moonCenter = CGPoint(x: size.width - moonRadius - 18, y: moonRadius + 10)
                context.drawLayer { moon in
                    moon.fill(
                        Path(ellipseIn: CGRect(
                            x: moonCenter.x - moonRadius,
                            y: moonCenter.y - moonRadius,
                            width: moonRadius * 2,
                            height: moonRadius * 2
                        )),
                        with: .color(.white.opacity(0.82))
                    )
                    moon.blendMode = .destinationOut
                    moon.fill(
                        Path(ellipseIn: CGRect(
                            x: moonCenter.x - moonRadius * 0.35,
                            y: moonCenter.y - moonRadius * 1.08,
                            width: moonRadius * 2,
                            height: moonRadius * 2
                        )),
                        with: .color(.white)
                    )
                }

                if shootingPhase < 0.28, isPlaying, !reduceMotion {
                    let progress = shootingPhase / 0.28
                    let cycle = Int(floor(time / ThemeAnimation.shootingStarPeriod))
                    let lane = Double(cycle % 3)
                    let head = CGPoint(
                        x: size.width * (0.08 + progress * 0.62),
                        y: size.height * (0.08 + lane * 0.08 + progress * 0.28)
                    )
                    let tail = CGPoint(x: head.x - 34, y: head.y - 17)
                    var path = Path()
                    path.move(to: tail)
                    path.addLine(to: head)
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [.clear, color.opacity(0.9)]),
                            startPoint: tail,
                            endPoint: head
                        ),
                        lineWidth: 1.5
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct RetroCRTMotif: View {
    let color: Color
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !isPlaying || reduceMotion)) { timeline in
            let phase = ThemeAnimation.phase(
                at: timeline.date.timeIntervalSinceReferenceDate,
                period: 3,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                var y: CGFloat = 2
                while y < size.height {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                        with: .color(color.opacity(0.035))
                    )
                    y += 4
                }

                let scanY = floor(CGFloat(phase) * size.height / 4) * 4
                context.fill(
                    Path(CGRect(x: 0, y: scanY, width: size.width, height: 2)),
                    with: .color(color.opacity(0.09))
                )
            }
            .allowsHitTesting(false)
        }
    }
}

struct PixelBorder: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cut: CGFloat = 8
            var outer = Path()
            outer.move(to: CGPoint(x: cut, y: 1))
            outer.addLine(to: CGPoint(x: size.width - cut, y: 1))
            outer.addLine(to: CGPoint(x: size.width - 1, y: cut))
            outer.addLine(to: CGPoint(x: size.width - 1, y: size.height - cut))
            outer.addLine(to: CGPoint(x: size.width - cut, y: size.height - 1))
            outer.addLine(to: CGPoint(x: cut, y: size.height - 1))
            outer.addLine(to: CGPoint(x: 1, y: size.height - cut))
            outer.addLine(to: CGPoint(x: 1, y: cut))
            outer.closeSubpath()
            context.stroke(outer, with: .color(color.opacity(0.9)), lineWidth: 2)

            let inset: CGFloat = 5
            context.stroke(
                Path(CGRect(
                    x: inset,
                    y: inset,
                    width: size.width - inset * 2,
                    height: size.height - inset * 2
                )),
                with: .color(color.opacity(0.3)),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
    }
}

struct PaperGrainMotif: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: !isPlaying || reduceMotion)) { timeline in
            let phase = ThemeAnimation.phase(
                at: timeline.date.timeIntervalSinceReferenceDate,
                period: 5,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                for index in 0..<70 {
                    let xSeed = CGFloat((index * 43) % 97) / 97
                    let ySeed = CGFloat((index * 31) % 89) / 89
                    let x = (xSeed + CGFloat(phase) * 0.015)
                        .truncatingRemainder(dividingBy: 1) * size.width
                    let y = ySeed * size.height
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.black.opacity(0.045))
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}
