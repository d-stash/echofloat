import Foundation

/// Polls the active YouTube Music tab in Google Chrome via AppleScript +
/// in-page JavaScript execution, since browser tabs have no Distributed
/// Notification or MediaRemote signal at all.
///
/// Requires two one-time user setup steps (documented in README):
///   1. Chrome > View > Developer > Allow JavaScript from Apple Events.
///   2. Approve the macOS Automation permission prompt for Echofloat -> Chrome.
/// Until both are granted, `osascript` calls fail silently and this source
/// simply yields nil, same as "nothing playing".
@MainActor
final class BrowserNowPlayingSource: MusicSource {
    private var continuation: AsyncStream<NowPlayingState?>.Continuation?
    private var pollTask: Task<Void, Never>?
    private var lastYielded: NowPlayingState?

    lazy var nowPlayingUpdates: AsyncStream<NowPlayingState?> = AsyncStream { [weak self] continuation in
        guard let self else { return }
        self.continuation = continuation
        self.startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let state = await Self.queryYouTubeMusicTab()
                if state != self.lastYielded {
                    self.lastYielded = state
                    self.continuation?.yield(state)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private static func queryYouTubeMusicTab() async -> NowPlayingState? {
        guard let raw = try? await AppleScriptRunner.run(findAndReadScript), raw != "null" else { return nil }
        guard let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(YouTubeMusicPayload.self, from: data) else { return nil }
        guard !payload.title.isEmpty else { return nil }

        let track = TrackSignature(
            title: payload.title,
            artist: payload.artist.isEmpty ? "Unknown Artist" : payload.artist,
            album: nil,
            durationSeconds: payload.duration.isFinite ? Int(payload.duration) : nil
        )
        return NowPlayingState(
            track: track,
            sourceAppName: "YouTube Music",
            status: payload.playing ? .playing : .paused,
            elapsedSeconds: payload.currentTime,
            capturedAt: Date()
        )
    }

    func play() { runPlayerCommand("var v=document.querySelector('video'); if(v) v.play();") }
    func pause() { runPlayerCommand("var v=document.querySelector('video'); if(v) v.pause();") }
    func next() { runPlayerCommand("document.querySelector('.next-button, tp-yt-paper-icon-button.next-button')?.click();") }
    func previous() { runPlayerCommand("document.querySelector('.previous-button, tp-yt-paper-icon-button.previous-button')?.click();") }

    private func runPlayerCommand(_ js: String) {
        AppleScriptRunner.fireAndForget(Self.findAndRunScript("(function(){\(js)})();"))
    }

    /// Locates the first Chrome tab whose URL is on music.youtube.com and reads
    /// metadata plus track-relative timing from the player controls.
    ///
    /// YouTube Music has rolled out a "player page modernization" redesign (behind
    /// the `is-mweb-player-page-modernization-enabled` attribute on
    /// `ytmusic-player-bar`) on some accounts, which leaves the legacy `.title`/
    /// `.byline` elements present but empty. Rather than chase fragile internal
    /// class names again, fall back to the standard `navigator.mediaSession.metadata`
    /// Web API (which YouTube Music always populates for OS media controls) whenever
    /// the DOM scrape comes back blank.
    static let playbackReadJavaScript = """
        (function(){
          var v = document.querySelector('video');
          var progress = document.querySelector('ytmusic-player-bar #progress-bar, #progress-bar');
          var titleEl = document.querySelector('.ytmusic-player-bar .title, ytmusic-player-bar .title');
          var artistEl = document.querySelector('.ytmusic-player-bar .byline, ytmusic-player-bar .byline');
          var domTitle = titleEl ? titleEl.textContent.trim() : '';
          var domArtistRaw = artistEl ? artistEl.textContent.trim() : '';
          var domArtist = domArtistRaw.split(' • ')[0] || domArtistRaw;
          var mediaMeta = (navigator.mediaSession && navigator.mediaSession.metadata) ? navigator.mediaSession.metadata : null;
          var title = domTitle || (mediaMeta && mediaMeta.title ? mediaMeta.title.trim() : '');
          var artist = domArtist || (mediaMeta && mediaMeta.artist ? mediaMeta.artist.trim() : '');
          var currentTime = Number(progress ? progress.getAttribute('aria-valuenow') : NaN);
          var duration = Number(progress ? progress.getAttribute('aria-valuemax') : NaN);
          return JSON.stringify({
            title: title,
            artist: artist,
            playing: v ? !v.paused : false,
            currentTime: Number.isFinite(currentTime) ? currentTime : 0,
            duration: Number.isFinite(duration) ? duration : 0
          });
        })();
        """

    private static let findAndReadScript = findAndRunScript(playbackReadJavaScript)

    private static func findAndRunScript(_ js: String) -> String {
        """
        if application "Google Chrome" is not running then return "null"
        tell application "Google Chrome"
            set foundTab to missing value
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t contains "music.youtube.com") then
                        set foundTab to t
                        exit repeat
                    end if
                end repeat
                if foundTab is not missing value then exit repeat
            end repeat
            if foundTab is missing value then return "null"
            return execute foundTab javascript "\(js)"
        end tell
        """
    }
}

private struct YouTubeMusicPayload: Decodable {
    let title: String
    let artist: String
    let playing: Bool
    let currentTime: Double
    let duration: Double
}
