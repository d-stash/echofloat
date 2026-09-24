import SwiftUI
import Testing
@testable import echofloat

@Test @MainActor func plainLyricsShowComingSoonMessageInsteadOfRawText() {
    let view = LyricsStackView(
        lyrics: .plain("A whole paragraph of unsynced lyrics that would otherwise get clipped"),
        currentIndex: nil,
        fallbackTitle: "Now Playing",
        accentColor: .white,
        secondaryColor: .gray,
        fontDesign: .default,
        currentLineSize: 16,
        otherLineSize: 11
    )
    let lines = view.visibleLines(maxLines: 3)
    #expect(lines == [
        LyricsStackView.Line(offset: 0, text: LyricsStackView.syncedLyricsComingSoonMessage, isCurrent: true),
    ])
}

@Test @MainActor func syncedLyricsStillShowActualLines() {
    let view = LyricsStackView(
        lyrics: .synced([LyricLine(timestamp: 0, text: "Hello")]),
        currentIndex: 0,
        fallbackTitle: "Now Playing",
        accentColor: .white,
        secondaryColor: .gray,
        fontDesign: .default,
        currentLineSize: 16,
        otherLineSize: 11
    )
    let lines = view.visibleLines(maxLines: 3)
    #expect(lines == [LyricsStackView.Line(offset: 0, text: "Hello", isCurrent: true)])
}
