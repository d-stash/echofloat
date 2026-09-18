import SwiftUI

struct CollapsedPillView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme
    let onHoverChanged: (Bool) -> Void

    var body: some View {
        ZStack {
            LiquidGlassBackground(theme: theme)
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .foregroundStyle(Color(hex: theme.accentColorHex))
                Text(currentLineText)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
        }
        .clipShape(Capsule())
        .onHover(perform: onHoverChanged)
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
