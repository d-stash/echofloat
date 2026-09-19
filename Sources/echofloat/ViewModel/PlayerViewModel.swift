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
    private var listenTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var lyricTickerTask: Task<Void, Never>?
    private var lifecycleVersion = 0

    init(musicSource: MusicSource, lyricsProvider: LyricsProvider, cache: LyricsCache) {
        self.musicSource = musicSource
        self.lyricsProvider = lyricsProvider
        self.cache = cache
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
        lyricsTask?.cancel()
        lyricsTask = nil
        lyricTickerTask?.cancel()
        lyricTickerTask = nil
        lifecycleVersion += 1
    }

    private func handle(_ state: NowPlayingState?, version: Int) {
        let previousTrack = nowPlaying?.track
        nowPlaying = state
        guard let state else {
            lyricsTask?.cancel()
            lyricsTask = nil
            lyrics = .notFound
            currentLineIndex = nil
            return
        }

        if state.track != previousTrack {
            lyricsTask?.cancel()
            lyricsTask = nil
            if let cached = cache.load(for: state.track) {
                lyrics = cached
            } else {
                let track = state.track
                lyricsTask = Task { [weak self] in
                    guard let self else { return }
                    let fetched = await self.lyricsProvider.lyrics(for: track)
                    guard !Task.isCancelled else { return }
                    self.publish(fetched, for: track, version: version)
                }
            }
        }
        updateCurrentLine(elapsed: state.elapsedSeconds)
    }

    private func publish(_ fetched: LyricsResult, for track: TrackSignature, version: Int) {
        guard version == lifecycleVersion,
              nowPlaying?.track == track,
              !Task.isCancelled else { return }
        lyrics = fetched
        cache.store(fetched, for: track)
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
