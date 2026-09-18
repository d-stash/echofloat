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
                await self.handle(state, version: version)
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
        lifecycleVersion += 1
    }

    private func handle(_ state: NowPlayingState?, version: Int) async {
        let previousTrack = nowPlaying?.track
        nowPlaying = state
        guard let state else {
            lyrics = .notFound
            currentLineIndex = nil
            return
        }

        if state.track != previousTrack {
            if let cached = cache.load(for: state.track) {
                lyrics = cached
            } else {
                let fetched = await lyricsProvider.lyrics(for: state.track)
                guard !Task.isCancelled, version == lifecycleVersion else { return }
                lyrics = fetched
                cache.store(fetched, for: state.track)
            }
        }
        updateCurrentLine(elapsed: state.elapsedSeconds)
    }

    private func updateCurrentLine(elapsed: Double) {
        guard case .synced(let lines) = lyrics, !lines.isEmpty else {
            currentLineIndex = nil
            return
        }

        var index: Int?
        for (indexValue, line) in lines.enumerated() where line.timestamp <= elapsed {
            index = indexValue
        }
        currentLineIndex = index
    }

    func playPause() {
        if nowPlaying?.status == .playing {
            musicSource.pause()
        } else {
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
