@preconcurrency import Foundation

/// Reads public playback notifications from Music and Spotify, then corrects
/// elapsed time with AppleScript while the selected player is active.
@MainActor
final class DistributedNowPlayingSource: MusicSource {
    private enum Player: String, CaseIterable, Sendable {
        case music = "Music"
        case spotify = "Spotify"

        var notificationName: NSNotification.Name {
            switch self {
            case .music:
                NSNotification.Name("com.apple.Music.playerInfo")
            case .spotify:
                NSNotification.Name("com.spotify.client.PlaybackStateChanged")
            }
        }
    }

    private static let snapshotSeparator = "\u{1F}"

    private struct NotificationPayload: Sendable {
        let title: String?
        let artist: String?
        let album: String?
        let durationSeconds: Int?
        let isPlaying: Bool
    }

    private let scriptExecutor: AppleScriptExecuting
    private let notificationCenter: DistributedNotificationCenter?
    private let positionPollIntervalNanoseconds: UInt64?
    private let loadsInitialSnapshots: Bool
    private var continuation: AsyncStream<NowPlayingState?>.Continuation?
    private var observers: [NSObjectProtocol] = []
    private var observationTask: Task<Void, Never>?
    private var positionPollTask: Task<Void, Never>?
    private var states: [Player: NowPlayingState] = [:]
    private var stateRevisions: [Player: UInt64] = [:]
    private var playingRecency: [Player: Int] = [:]
    private var playersUpdatedByNotification: Set<Player> = []
    private var activityCounter = 0
    private var selectedPlayer: Player?

    init(
        scriptExecutor: AppleScriptExecuting = LiveAppleScriptExecutor(),
        notificationCenter: DistributedNotificationCenter? = .default(),
        positionPollIntervalNanoseconds: UInt64? = 1_000_000_000,
        loadsInitialSnapshots: Bool = true
    ) {
        self.scriptExecutor = scriptExecutor
        self.notificationCenter = notificationCenter
        self.positionPollIntervalNanoseconds = positionPollIntervalNanoseconds
        self.loadsInitialSnapshots = loadsInitialSnapshots
    }

    lazy var nowPlayingUpdates: AsyncStream<NowPlayingState?> = AsyncStream { [weak self] continuation in
        guard let self else { return }
        self.continuation = continuation
        self.startObserving()
        if loadsInitialSnapshots {
            self.loadInitialSnapshots()
        }
        self.startPositionPolling()
    }

    deinit {
        if let notificationCenter {
            observers.forEach { notificationCenter.removeObserver($0) }
        }
        observationTask?.cancel()
        positionPollTask?.cancel()
    }

    private func startObserving() {
        guard let notificationCenter else { return }
        observers = Player.allCases.map { player in
            notificationCenter.addObserver(
                forName: player.notificationName,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let payload = Self.notificationPayload(from: note.userInfo ?? [:])
                Task { @MainActor [weak self] in
                    self?.receive(payload, from: player, capturedAt: Date())
                }
            }
        }
    }

    private func loadInitialSnapshots() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            var snapshots: [(Player, NowPlayingState?)] = []
            for player in Player.allCases {
                snapshots.append((player, await self.querySnapshot(for: player)))
            }
            for (player, state) in snapshots {
                if !self.playersUpdatedByNotification.contains(player) {
                    self.update(state, for: player, recordsActivity: false)
                }
            }
        }
    }

    func receive(
        _ info: [AnyHashable: Any],
        appName: String,
        capturedAt: Date = Date()
    ) {
        guard let player = Player(rawValue: appName) else { return }
        playersUpdatedByNotification.insert(player)
        receive(Self.notificationPayload(from: info), from: player, capturedAt: capturedAt)
    }

    private func receive(
        _ payload: NotificationPayload,
        from player: Player,
        capturedAt: Date
    ) {
        guard let title = payload.title, !title.isEmpty else {
            update(nil, for: player, recordsActivity: false)
            return
        }

        let state = NowPlayingState(
            track: TrackSignature(
                title: title,
                artist: payload.artist ?? "Unknown Artist",
                album: payload.album,
                durationSeconds: payload.durationSeconds
            ),
            sourceAppName: player.rawValue,
            status: payload.isPlaying ? .playing : .paused,
            elapsedSeconds: 0,
            capturedAt: capturedAt
        )
        update(state, for: player, recordsActivity: payload.isPlaying)
    }

    private func update(
        _ state: NowPlayingState?,
        for player: Player,
        recordsActivity: Bool
    ) {
        stateRevisions[player, default: 0] &+= 1
        states[player] = state
        if recordsActivity {
            activityCounter += 1
            playingRecency[player] = activityCounter
        }
        selectedPlayer = selectPlayer()
        continuation?.yield(selectedPlayer.flatMap { states[$0] })
    }

    private func selectPlayer() -> Player? {
        let playing = Player.allCases.filter { states[$0]?.status == .playing }
        if !playing.isEmpty {
            return playing.max {
                let left = playingRecency[$0, default: 0]
                let right = playingRecency[$1, default: 0]
                return left == right
                    ? Player.allCases.firstIndex(of: $0)! > Player.allCases.firstIndex(of: $1)!
                    : left < right
            }
        }
        if let selectedPlayer,
           playingRecency[selectedPlayer] != nil,
           states[selectedPlayer] != nil {
            return selectedPlayer
        }
        let paused = Player.allCases.filter { states[$0] != nil }
        return paused.max {
            let left = playingRecency[$0, default: 0]
            let right = playingRecency[$1, default: 0]
            return left == right
                ? Player.allCases.firstIndex(of: $0)! > Player.allCases.firstIndex(of: $1)!
                : left < right
        }
    }

    nonisolated private static func notificationPayload(
        from info: [AnyHashable: Any]
    ) -> NotificationPayload {
        let stateString = info["Player State"] as? String ?? ""
        return NotificationPayload(
            title: info["Name"] as? String,
            artist: info["Artist"] as? String,
            album: info["Album"] as? String,
            durationSeconds: durationSeconds(from: info),
            isPlaying: stateString.caseInsensitiveCompare("Playing") == .orderedSame
        )
    }

    nonisolated private static func durationSeconds(from info: [AnyHashable: Any]) -> Int? {
        if let ms = info["Total Time"] as? Double { return Int(ms / 1000) }
        if let ms = info["Duration"] as? Double { return Int(ms / 1000) }
        return nil
    }

    private func startPositionPolling() {
        guard let interval = positionPollIntervalNanoseconds else { return }
        positionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let player = self.selectedPlayer,
                   let current = self.states[player],
                   current.status == .playing {
                    let revision = self.stateRevisions[player, default: 0]
                    if let elapsed = try? await self.queryPosition(for: player) {
                        if self.selectedPlayer == player,
                           self.stateRevisions[player] == revision,
                           let latest = self.states[player],
                           latest.status == .playing,
                           latest.track == current.track {
                            self.states[player] = NowPlayingState(
                                track: latest.track,
                                sourceAppName: latest.sourceAppName,
                                status: latest.status,
                                elapsedSeconds: elapsed,
                                capturedAt: Date()
                            )
                            self.continuation?.yield(self.states[player])
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func queryPosition(for player: Player) async throws -> Double? {
        let script = "tell application \"\(player.rawValue)\" to get player position"
        guard let output = try await scriptExecutor.run(script) else { return nil }
        return Double(output)
    }

    private func querySnapshot(for player: Player) async -> NowPlayingState? {
        guard let output = try? await scriptExecutor.run(Self.snapshotScript(for: player)) else {
            return nil
        }
        let fields = output.components(separatedBy: Self.snapshotSeparator)
        guard fields.count == 6, !fields[0].isEmpty else { return nil }
        let status: NowPlayingState.PlaybackStatus =
            fields[4].caseInsensitiveCompare("playing") == .orderedSame ? .playing : .paused
        return NowPlayingState(
            track: TrackSignature(
                title: fields[0],
                artist: fields[1].isEmpty ? "Unknown Artist" : fields[1],
                album: fields[2].isEmpty ? nil : fields[2],
                durationSeconds: Double(fields[3]).map(Int.init)
            ),
            sourceAppName: player.rawValue,
            status: status,
            elapsedSeconds: Double(fields[5]) ?? 0,
            capturedAt: Date()
        )
    }

    private static func snapshotScript(for player: Player) -> String {
        let durationExpression = player == .spotify
            ? "(duration of current track) / 1000"
            : "duration of current track"
        return """
        if application "\(player.rawValue)" is not running then return ""
        tell application "\(player.rawValue)"
            if player state is stopped then return ""
            set separator to ASCII character 31
            return (name of current track) & separator & (artist of current track) & separator & (album of current track) & separator & (\(durationExpression) as text) & separator & (player state as text) & separator & (player position as text)
        end tell
        """
    }

    static func snapshotOutput(
        title: String,
        artist: String,
        album: String,
        duration: Double,
        state: String,
        position: Double
    ) -> String {
        [title, artist, album, String(duration), state, String(position)]
            .joined(separator: snapshotSeparator)
    }

    private var selectedAppName: String {
        selectedPlayer?.rawValue ?? Player.music.rawValue
    }

    func play() {
        scriptExecutor.fireAndForget("tell application \"\(selectedAppName)\" to play")
    }

    func pause() {
        scriptExecutor.fireAndForget("tell application \"\(selectedAppName)\" to pause")
    }

    func next() {
        scriptExecutor.fireAndForget("tell application \"\(selectedAppName)\" to next track")
    }

    func previous() {
        scriptExecutor.fireAndForget("tell application \"\(selectedAppName)\" to previous track")
    }
}
