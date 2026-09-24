import Testing
@testable import echofloat

@Test @MainActor func browserPlaybackUsesTrackRelativeProgress() {
    let script = BrowserNowPlayingSource.playbackReadJavaScript

    #expect(script.contains("aria-valuenow"))
    #expect(script.contains("aria-valuemax"))
    #expect(!script.contains("v.currentTime"))
    #expect(!script.contains("v.duration"))
}

/// Regression test for YouTube Music's "player page modernization" redesign,
/// which leaves the legacy `.title`/`.byline` elements present but empty.
/// The script must fall back to `navigator.mediaSession.metadata` in that case.
@Test @MainActor func browserPlaybackFallsBackToMediaSessionMetadataWhenDomIsEmpty() {
    let script = BrowserNowPlayingSource.playbackReadJavaScript

    #expect(script.contains("navigator.mediaSession"))
    #expect(script.contains("mediaMeta.title"))
    #expect(script.contains("mediaMeta.artist"))
    #expect(script.contains("domTitle || "))
    #expect(script.contains("domArtist || "))
}
