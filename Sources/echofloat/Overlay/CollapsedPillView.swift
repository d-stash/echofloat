import SwiftUI

struct CollapsedPillView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme

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
    }

    private var currentLineText: String {
        if case .synced(let lines) = viewModel.lyrics, let index = viewModel.currentLineIndex {
            return lines[index].text
        }
        return viewModel.nowPlaying?.track.title ?? "Nothing playing"
    }
}
