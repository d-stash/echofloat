import Foundation
import JavaScriptCore
import Testing
@testable import echofloat

@Test @MainActor func browserPlaybackUsesTrackRelativeProgress() {
    let script = BrowserNowPlayingSource.playbackReadJavaScript

    #expect(script.contains("aria-valuenow"))
    #expect(script.contains("aria-valuemax"))
    #expect(script.contains("v.currentTime"))
    #expect(script.contains("v.duration"))
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

@Test @MainActor func browserPlaybackFallsBackToVideoPositionWhenProgressARIAIsMissing() throws {
    let context = try #require(JSContext())
    context.evaluateScript("""
        var video = { paused: false, currentTime: 42.5, duration: 247 };
        var progress = { getAttribute: function() { return null; } };
        var document = {
            querySelector: function(selector) {
                if (selector === 'video') return video;
                if (selector.indexOf('progress') >= 0 || selector === '#progress-bar') return progress;
                return null;
            }
        };
        var navigator = {};
        """)

    let output = try #require(
        context.evaluateScript(BrowserNowPlayingSource.playbackReadJavaScript)?.toString()
    )
    let data = try #require(output.data(using: .utf8))
    let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(payload["currentTime"] as? Double == 42.5)
    #expect(payload["duration"] as? Double == 247)
}
