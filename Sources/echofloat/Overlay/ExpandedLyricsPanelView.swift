import SwiftUI

struct ExpandedLyricsPanelView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme

    var body: some View {
        ZStack {
            LiquidGlassBackground(theme: theme)
            VStack(spacing: 12) {
                Text(viewModel.nowPlaying?.track.title ?? "Nothing playing")
                    .font(.headline)
                Text(viewModel.nowPlaying?.sourceAppName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(lyricLines.enumerated()), id: \.offset) { index, line in
                                Text(line.text)
                                    .font(index == viewModel.currentLineIndex ? .title3.bold() : .body)
                                    .foregroundStyle(
                                        index == viewModel.currentLineIndex
                                            ? Color(hex: theme.accentColorHex)
                                            : .white.opacity(0.6)
                                    )
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: viewModel.currentLineIndex) { newValue in
                        guard let newValue else { return }
                        withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                    }
                }
                HStack(spacing: 24) {
                    Button(action: viewModel.previous) { Image(systemName: "backward.fill") }
                    Button(action: viewModel.playPause) {
                        Image(systemName: viewModel.nowPlaying?.status == .playing ? "pause.fill" : "play.fill")
                    }
                    Button(action: viewModel.next) { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var lyricLines: [LyricLine] {
        if case .synced(let lines) = viewModel.lyrics { return lines }
        return []
    }
}
