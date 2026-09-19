import SwiftUI

/// The whole overlay is now a single fixed widget (no hover-expand/collapse state
/// machine): a compact lyrics line on top, and a mini playback control row below,
/// stacked vertically per user request rather than side-by-side.
struct MiniPlayerBarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme
    let defaultOrigin: () -> CGPoint

    var body: some View {
        ZStack {
            LiquidGlassBackground(theme: theme)
            DragHandleView(defaultOrigin: defaultOrigin)
            VStack(spacing: 6) {
                Text(currentLineText)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 20) {
                    transportButton("backward.fill", action: viewModel.previous)
                    transportButton(
                        viewModel.nowPlaying?.status == .playing ? "pause.fill" : "play.fill",
                        action: viewModel.playPause
                    )
                    transportButton("forward.fill", action: viewModel.next)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func transportButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(Color(hex: theme.accentColorHex))
        }
        .buttonStyle(.plain)
    }

    private var currentLineText: String {
        if case .synced(let lines) = viewModel.lyrics, let index = viewModel.currentLineIndex {
            return lines[index].text
        }
        if case .plain(let text) = viewModel.lyrics, !text.isEmpty {
            return text
        }
        return viewModel.nowPlaying?.track.title ?? "Nothing playing"
    }
}
