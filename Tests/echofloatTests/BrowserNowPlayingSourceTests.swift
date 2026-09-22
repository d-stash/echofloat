import Testing
@testable import echofloat

@Test @MainActor func browserPlaybackUsesTrackRelativeProgress() {
    let script = BrowserNowPlayingSource.playbackReadJavaScript

    #expect(script.contains("aria-valuenow"))
    #expect(script.contains("aria-valuemax"))
    #expect(!script.contains("v.currentTime"))
    #expect(!script.contains("v.duration"))
}
