import SwiftUI

/// Single fixed overlay widget: a lyrics area on top that reflows to show more
/// context lines (before/after the current line) as the panel is resized
/// taller, and a mini playback control row pinned at the bottom, visually
/// separated by a divider + subtle background tint.
struct MiniPlayerBarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme
    let defaultOrigin: () -> CGPoint

    var body: some View {
        ZStack {
            LiquidGlassBackground(theme: theme)
            DragHandleView(defaultOrigin: defaultOrigin)
            VStack(spacing: 0) {
                lyricsArea
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)

                HStack(spacing: 22) {
                    transportButton("backward.fill", action: viewModel.previous)
                    transportButton(
                        viewModel.nowPlaying?.status == .playing ? "pause.fill" : "play.fill",
                        action: viewModel.playPause
                    )
                    transportButton("forward.fill", action: viewModel.next)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.15))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var lyricsArea: some View {
        if viewModel.nowPlaying == nil {
            Text("Nothing playing")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LyricsStackView(
                lyrics: viewModel.lyrics,
                currentIndex: viewModel.currentLineIndex,
                fallbackTitle: viewModel.nowPlaying?.track.title ?? "",
                accentColor: Color(hex: theme.accentColorHex)
            )
        }
    }

    private func transportButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(Color(hex: theme.accentColorHex))
                .shadow(color: Color(hex: theme.accentColorHex).opacity(0.7), radius: 4)
        }
        .buttonStyle(.plain)
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

    private let lineHeight: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let maxLines = max(1, Int(geo.size.height / lineHeight))
            VStack(spacing: 2) {
                ForEach(visibleLines(maxLines: maxLines), id: \.offset) { line in
                    Text(line.text)
                        .font(line.isCurrent ? .callout.bold() : .caption2)
                        .foregroundStyle(line.isCurrent ? accentColor : .white.opacity(0.55))
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
        default:
            return [Line(offset: 0, text: fallbackTitle, isCurrent: true)]
        }
    }
}
