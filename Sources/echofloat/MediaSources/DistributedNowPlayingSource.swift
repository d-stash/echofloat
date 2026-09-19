import Foundation

/// Reads now-playing state from the public Distributed Notifications that
/// Music.app and Spotify broadcast on every track/state change.
///
/// This deliberately avoids the private MediaRemote framework: as of macOS
/// Sonoma 15.3+, `MRMediaRemoteGetNowPlayingInfo` returns an empty
/// dictionary for any process that isn't Apple-signed, so that API is no
/// longer usable by third-party apps (confirmed via direct probing). These
/// distributed notifications are a separate, public, per-app mechanism
/// unaffected by that lockdown.
///
/// Trade-off: neither app's notification carries playback position, so this
/// source estimates elapsed time via a cheap AppleScript position poll once
/// a second while something is playing.
final class DistributedNowPlayingSource: MusicSource {
    private static let musicNotificationName = NSNotification.Name("com.apple.Music.playerInfo")
    private static let spotifyNotificationName = NSNotification.Name("com.spotify.client.PlaybackStateChanged")

    private var continuation: AsyncStream<NowPlayingState?>.Continuation?
    private var observers: [NSObjectProtocol] = []
    private var positionPollTask: Task<Void, Never>?
    private var lastState: NowPlayingState?

    lazy var nowPlayingUpdates: AsyncStream<NowPlayingState?> = AsyncStream { [weak self] continuation in
        guard let self else { return }
        self.continuation = continuation
        self.startObserving()
        self.startPositionPolling()
    }

    deinit {
        let center = DistributedNotificationCenter.default()
        observers.forEach { center.removeObserver($0) }
        positionPollTask?.cancel()
    }

    private func startObserving() {
        let center = DistributedNotificationCenter.default()
        let music = center.addObserver(
            forName: Self.musicNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handle(note, appName: "Music")
        }
        let spotify = center.addObserver(
            forName: Self.spotifyNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handle(note, appName: "Spotify")
        }
        observers = [music, spotify]
    }

    private func handle(_ note: Notification, appName: String) {
        guard let info = note.userInfo, let title = info["Name"] as? String, !title.isEmpty else {
            lastState = nil
            continuation?.yield(nil)
            return
        }

        let artist = info["Artist"] as? String ?? "Unknown Artist"
        let album = info["Album"] as? String
        let durationSeconds = durationSeconds(from: info)
        let stateString = info["Player State"] as? String ?? ""
        let isPlaying = stateString.caseInsensitiveCompare("Playing") == .orderedSame

        let track = TrackSignature(title: title, artist: artist, album: album, durationSeconds: durationSeconds)
        let state = NowPlayingState(
            track: track,
            sourceAppName: appName,
            status: isPlaying ? .playing : .paused,
            elapsedSeconds: 0,
            capturedAt: Date()
        )
        lastState = state
        continuation?.yield(state)
    }

    private func durationSeconds(from info: [AnyHashable: Any]) -> Int? {
        // Music.app broadcasts "Total Time" in ms; Spotify broadcasts "Duration" in ms.
        if let ms = info["Total Time"] as? Double { return Int(ms / 1000) }
        if let ms = info["Duration"] as? Double { return Int(ms / 1000) }
        return nil
    }

    private func startPositionPolling() {
        positionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                if let self, let current = self.lastState, current.status == .playing,
                   let elapsed = try? await Self.queryPosition(appName: current.sourceAppName) {
                    let refreshed = NowPlayingState(
                        track: current.track,
                        sourceAppName: current.sourceAppName,
                        status: current.status,
                        elapsedSeconds: elapsed,
                        capturedAt: Date()
                    )
                    self.lastState = refreshed
                    self.continuation?.yield(refreshed)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private static func queryPosition(appName: String) async throws -> Double? {
        let script = "tell application \"\(appName)\" to get player position"
        guard let output = try await AppleScriptRunner.run(script) else { return nil }
        return Double(output)
    }

    func play() { AppleScriptRunner.fireAndForget("tell application \"\(lastState?.sourceAppName ?? "Music")\" to play") }
    func pause() { AppleScriptRunner.fireAndForget("tell application \"\(lastState?.sourceAppName ?? "Music")\" to pause") }
    func next() { AppleScriptRunner.fireAndForget("tell application \"\(lastState?.sourceAppName ?? "Music")\" to next track") }
    func previous() { AppleScriptRunner.fireAndForget("tell application \"\(lastState?.sourceAppName ?? "Music")\" to previous track") }
}
