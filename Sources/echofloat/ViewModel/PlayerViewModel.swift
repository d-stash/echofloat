import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var nowPlaying: NowPlayingState?
    @Published private(set) var lyrics: LyricsResult = .notFound
    @Published private(set) var currentLineIndex: Int?

    private let musicSource: MusicSource
    private let lyricsProvider: LyricsProvider
    private let cache: LyricsCache
    private let lyricsRetryBaseNanoseconds: UInt64
    private let lyricsRetryMaximumNanoseconds: UInt64
    private var listenTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var lyricTickerTask: Task<Void, Never>?
    private var lifecycleVersion = 0
    private var lyricsRequestGeneration = 0
    private var lyricsRetryAttempt = 0

    init(
        musicSource: MusicSource,
        lyricsProvider: LyricsProvider,
        cache: LyricsCache,
        lyricsRetryBaseNanoseconds: UInt64 = 1_000_000_000,
        lyricsRetryMaximumNanoseconds: UInt64 = 30_000_000_000
    ) {
        self.musicSource = musicSource
        self.lyricsProvider = lyricsProvider
        self.cache = cache
        let safeRetryBase = max(100_000_000, lyricsRetryBaseNanoseconds)
        self.lyricsRetryBaseNanoseconds = safeRetryBase
        self.lyricsRetryMaximumNanoseconds = max(
            safeRetryBase,
            lyricsRetryMaximumNanoseconds
        )
    }

    func start() {
        listenTask?.cancel()
        lifecycleVersion += 1
        let version = lifecycleVersion
        listenTask = Task { [weak self] in
            guard let self else { return }
            for await state in self.musicSource.nowPlayingUpdates {
                self.handle(state, version: version)
            }
        }
        lyricTickerTask?.cancel()
        lyricTickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self else { return }
                guard let state = self.nowPlaying else { continue }
                self.updateCurrentLine(elapsed: PlaybackClock.estimatedElapsed(for: state))
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
        cancelLyricsRequest()
        lyricTickerTask?.cancel()
        lyricTickerTask = nil
        lifecycleVersion += 1
    }

    private func handle(_ state: NowPlayingState?, version: Int) {
        let previousTrack = nowPlaying?.track
        nowPlaying = state
        guard let state else {
            cancelLyricsRequest()
            lyricsRetryAttempt = 0
            lyrics = .notFound
            currentLineIndex = nil
            return
        }

        if state.track != previousTrack {
            cancelLyricsRequest()
            lyricsRetryAttempt = 0
            if let cached = cache.load(for: state.track) {
                lyrics = cached
            } else {
                startLyricsRequest(for: state.track, version: version)
            }
        } else if lyrics == .unavailable, lyricsTask == nil {
            startLyricsRequest(
                for: state.track,
                version: version,
                delayNanoseconds: retryDelayNanoseconds()
            )
        }
        updateCurrentLine(elapsed: state.elapsedSeconds)
    }

    private func startLyricsRequest(
        for track: TrackSignature,
        version: Int,
        delayNanoseconds: UInt64 = 0
    ) {
        lyricsRequestGeneration += 1
        let requestGeneration = lyricsRequestGeneration
        lyricsTask = Task { [weak self] in
            guard let self else { return }
            if delayNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            let fetched = await self.lyricsProvider.lyrics(for: track)
            guard !Task.isCancelled else { return }
            self.completeLyricsRequest(
                fetched,
                for: track,
                version: version,
                requestGeneration: requestGeneration
            )
        }
    }

    private func completeLyricsRequest(
        _ fetched: LyricsResult,
        for track: TrackSignature,
        version: Int,
        requestGeneration: Int
    ) {
        guard requestGeneration == lyricsRequestGeneration,
              version == lifecycleVersion,
              nowPlaying?.track == track else {
            return
        }
        lyricsTask = nil
        publish(fetched, for: track, version: version)
        if fetched == .unavailable {
            lyricsRetryAttempt += 1
            startLyricsRequest(
                for: track,
                version: version,
                delayNanoseconds: retryDelayNanoseconds()
            )
        } else {
            lyricsRetryAttempt = 0
        }
    }

    private func cancelLyricsRequest() {
        lyricsRequestGeneration += 1
        lyricsTask?.cancel()
        lyricsTask = nil
    }

    private func retryDelayNanoseconds() -> UInt64 {
        var delay = lyricsRetryBaseNanoseconds
        guard lyricsRetryAttempt > 1 else { return delay }
        for _ in 1..<lyricsRetryAttempt {
            if delay >= lyricsRetryMaximumNanoseconds / 2 {
                return lyricsRetryMaximumNanoseconds
            }
            delay *= 2
        }
        return min(delay, lyricsRetryMaximumNanoseconds)
    }

    private func publish(_ fetched: LyricsResult, for track: TrackSignature, version: Int) {
        guard version == lifecycleVersion,
              nowPlaying?.track == track,
              !Task.isCancelled else { return }
        lyrics = fetched
        if fetched == .unavailable {
            NSLog("Echofloat: Lyrics request temporarily unavailable for \(track.title)")
        } else {
            cache.store(fetched, for: track)
        }
        updateCurrentLine(elapsed: nowPlaying?.elapsedSeconds ?? 0)
    }

    private func updateCurrentLine(elapsed: Double) {
        guard case .synced(let lines) = lyrics, !lines.isEmpty else {
            if currentLineIndex != nil {
                currentLineIndex = nil
            }
            return
        }

        var index: Int?
        for (indexValue, line) in lines.enumerated() where line.timestamp <= elapsed {
            index = indexValue
        }
        if currentLineIndex != index {
            currentLineIndex = index
        }
    }

    func playPause() {
        guard let state = nowPlaying else {
            musicSource.play()
            return
        }
        if state.status == .playing {
            nowPlaying = NowPlayingState(
                track: state.track,
                sourceAppName: state.sourceAppName,
                status: .paused,
                elapsedSeconds: PlaybackClock.estimatedElapsed(for: state),
                capturedAt: Date()
            )
            musicSource.pause()
        } else {
            nowPlaying = NowPlayingState(
                track: state.track,
                sourceAppName: state.sourceAppName,
                status: .playing,
                elapsedSeconds: state.elapsedSeconds,
                capturedAt: Date()
            )
            musicSource.play()
        }
    }

    func next() {
        musicSource.next()
    }

    func previous() {
        musicSource.previous()
    }
}
