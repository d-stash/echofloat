import SwiftUI

/// Single fixed overlay widget, redesigned as one horizontal bar (album art,
/// title/artist, lyrics, transport controls, accessory icon) matching the
/// reference mini-player designs, while keeping the earlier resize-to-reveal-
/// more-lyric-lines behavior — the lyrics stack still grows with panel height.
struct MiniPlayerBarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme
    let defaultOrigin: (CGSize) -> CGPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPlaying: Bool {
        viewModel.nowPlaying?.status == .playing
    }

    var body: some View {
        ZStack {
            PanelBackground(theme: theme, isPlaying: isPlaying)
            DragHandleView(defaultOrigin: defaultOrigin)

            HStack(spacing: 12) {
                albumArt
                trackInfo
                lyricsArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                transportControls
                accessoryView
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var albumArt: some View {
        if theme.animationStyle == .vinylSpin {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || reduceMotion)) { timeline in
                let phase = ThemeAnimation.phase(
                    at: timeline.date.timeIntervalSinceReferenceDate,
                    period: 6,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion
                )
                VinylRecordView(accent: Color(hex: theme.accentColorHex))
                    .rotationEffect(.degrees(phase * 360))
            }
            .frame(width: 40, height: 40)
        } else {
            standardAlbumArt
        }
    }

    private var standardAlbumArt: some View {
        let shape = AnyShape(theme.albumArtShape == .circle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous)))
        return ZStack {
            shape.fill(Color(hex: theme.accentColorHex).opacity(0.18))
            Image(systemName: "music.note")
                .foregroundStyle(Color(hex: theme.accentColorHex))
            shape.stroke(Color(hex: theme.accentColorHex).opacity(0.6), lineWidth: 1)
        }
        .frame(width: 40, height: 40)
    }

    @ViewBuilder
    private var trackInfo: some View {
        if let track = viewModel.nowPlaying?.track {
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(.caption, design: theme.fontDesign).bold())
                    .foregroundStyle(theme.textColor)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(.caption2, design: theme.fontDesign))
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
            }
            .frame(width: 84, alignment: .leading)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var lyricsArea: some View {
        if viewModel.nowPlaying == nil {
            Text("Nothing playing")
                .font(.system(.caption, design: theme.fontDesign))
                .foregroundStyle(theme.secondaryTextColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LyricsStackView(
                lyrics: viewModel.lyrics,
                currentIndex: viewModel.currentLineIndex,
                fallbackTitle: viewModel.nowPlaying?.track.title ?? "",
                accentColor: Color(hex: theme.accentColorHex),
                secondaryColor: theme.secondaryTextColor,
                fontDesign: theme.fontDesign
            )
        }
    }

    private var transportControls: some View {
        HStack(spacing: 14) {
            transportButton("backward.fill", action: viewModel.previous)
            transportButton(
                viewModel.nowPlaying?.status == .playing ? "pause.fill" : "play.fill",
                action: viewModel.playPause
            )
            transportButton("forward.fill", action: viewModel.next)
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch theme.accessoryIcon {
        case .none:
            EmptyView()
        case .heart:
            Image(systemName: "heart")
                .foregroundStyle(Color(hex: theme.accentColorHex))
        case .ellipsis:
            Image(systemName: "ellipsis")
                .foregroundStyle(theme.secondaryTextColor)
        case .equalizer:
            EqualizerBarsView(
                color: Color(hex: theme.accentColorHex),
                isPlaying: isPlaying,
                pixelated: theme.animationStyle == .retroCRT
            )
                .frame(width: 26, height: 16)
        }
    }

    private func transportButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(Color(hex: theme.accentColorHex))
                .shadow(color: Color(hex: theme.accentColorHex).opacity(0.7), radius: 4)
        }
        .buttonStyle(TransportButtonStyle())
    }
}

private struct TransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Small animated bar-graph accessory (seen in several reference designs next to
/// the transport controls), pulsing while a track is playing and flat when paused.
private struct EqualizerBarsView: View {
    let color: Color
    let isPlaying: Bool
    let pixelated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isPlaying || reduceMotion)) { timeline in
            let phase = ThemeAnimation.phase(
                at: timeline.date.timeIntervalSinceReferenceDate,
                period: 1.7,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion
            )
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let wave = abs(sin(phase * .pi * 2 + Double(i) * 1.4))
                    let level = isPlaying && !reduceMotion ? 1 + Int(wave * 4) : 2
                    if pixelated {
                        PixelEqualizerBar(color: color, level: level)
                    } else {
                        Capsule()
                            .fill(color)
                            .frame(width: 3, height: CGFloat(level) / 5 * 16)
                    }
                }
            }
        }
    }
}

private struct PixelEqualizerBar: View {
    let color: Color
    let level: Int

    var body: some View {
        VStack(spacing: 1) {
            ForEach((0..<5).reversed(), id: \.self) { block in
                Rectangle()
                    .fill(color.opacity(block < level ? 1 : 0.12))
                    .frame(width: 4, height: 2)
            }
        }
    }
}

private struct VinylRecordView: View {
    let accent: Color

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.86))
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 1).padding(4)
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1).padding(8)
            Circle().fill(accent).frame(width: 13, height: 13)
            Circle().fill(Color.black.opacity(0.75)).frame(width: 3, height: 3)
            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 11, height: 1)
                .offset(x: 10)
        }
    }
}

/// Renders as many lyric lines as fit the available height, centered on the
/// currently-playing line, so growing the panel taller reveals more
/// upcoming/previous lines instead of just stretching a single line.
private struct LyricsStackView: View {
    let lyrics: LyricsResult
    let currentIndex: Int?
    let fallbackTitle: String
    let accentColor: Color
    let secondaryColor: Color
    let fontDesign: Font.Design

    private let lineHeight: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let maxLines = max(1, Int(geo.size.height / lineHeight))
            VStack(spacing: 2) {
                ForEach(visibleLines(maxLines: maxLines), id: \.offset) { line in
                    Text(line.text)
                        .font(.system(line.isCurrent ? .callout : .caption2, design: fontDesign).weight(line.isCurrent ? .bold : .regular))
                        .foregroundStyle(line.isCurrent ? accentColor : secondaryColor)
                        .shadow(color: line.isCurrent ? accentColor.opacity(0.6) : .clear, radius: 3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private struct Line: Identifiable {
        let offset: Int
        let text: String
        let isCurrent: Bool
        var id: Int { offset }
    }

    private func visibleLines(maxLines: Int) -> [Line] {
        switch lyrics {
        case .synced(let lines) where !lines.isEmpty:
            let current = min(currentIndex ?? 0, lines.count - 1)
            let before = (maxLines - 1) / 2
            let start = max(0, current - before)
            let end = min(lines.count, start + maxLines)
            let clampedStart = max(0, end - maxLines)
            return (clampedStart..<end).map { idx in
                Line(offset: idx, text: lines[idx].text, isCurrent: idx == current)
            }
        case .plain(let text) where !text.isEmpty:
            return [Line(offset: 0, text: text, isCurrent: true)]
        case .unavailable:
            return [Line(offset: 0, text: "Lyrics temporarily unavailable", isCurrent: true)]
        default:
            return [Line(offset: 0, text: fallbackTitle, isCurrent: true)]
        }
    }
}

/// Type-erased shape wrapper so albumArt can pick Circle vs RoundedRectangle at
/// runtime based on the theme without duplicating the whole view body.
private struct AnyShape: Shape {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}
