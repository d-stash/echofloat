import Foundation

/// Merges multiple `MusicSource`s into one stream. Whichever source most
/// recently reported an actively-playing track wins; when no source reports
/// `.playing`, yields nil (nothing playing). Playback commands are routed to
/// whichever source is currently "active" (the one behind the last non-nil
/// playing state), falling back to the first source if none is active yet.
@MainActor
final class CompositeNowPlayingSource: MusicSource {
    private let sources: [MusicSource]
    private var continuation: AsyncStream<NowPlayingState?>.Continuation?
    private var latestBySource: [Int: NowPlayingState?] = [:]
    private var activeSourceIndex: Int = 0
    private var sourceTasks: [Task<Void, Never>] = []
    let nowPlayingUpdates: AsyncStream<NowPlayingState?>

    init(sources: [MusicSource]) {
        precondition(!sources.isEmpty, "CompositeNowPlayingSource requires at least one source")
        self.sources = sources
        let (stream, continuation) = AsyncStream<NowPlayingState?>.makeStream()
        nowPlayingUpdates = stream
        self.continuation = continuation
        for (index, source) in self.sources.enumerated() {
            sourceTasks.append(Task { @MainActor [weak self, source] in
                for await state in source.nowPlayingUpdates {
                    guard let self else { return }
                    self.receive(state, from: index)
                }
            })
        }
    }

    deinit {
        sourceTasks.forEach { $0.cancel() }
    }

    private func receive(_ state: NowPlayingState?, from index: Int) {
        latestBySource[index] = state
        if let state, state.status == .playing {
            activeSourceIndex = index
            continuation?.yield(state)
            return
        }
        // Nothing new is playing from this source; only surface "nothing
        // playing" if the currently active source is the one that went idle.
        if index == activeSourceIndex {
            if let stillPlaying = latestBySource.first(where: { $0.value?.status == .playing }) {
                activeSourceIndex = stillPlaying.key
                continuation?.yield(stillPlaying.value ?? nil)
            } else {
                continuation?.yield(state)
            }
        }
    }

    func play() { sources[activeSourceIndex].play() }
    func pause() { sources[activeSourceIndex].pause() }
    func next() { sources[activeSourceIndex].next() }
    func previous() { sources[activeSourceIndex].previous() }
}
