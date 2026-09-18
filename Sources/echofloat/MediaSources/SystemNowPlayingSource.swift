import Foundation

final class SystemNowPlayingSource: MusicSource {
    private let client: MediaRemoteClient
    private var continuation: AsyncStream<NowPlayingState?>.Continuation?

    lazy var nowPlayingUpdates: AsyncStream<NowPlayingState?> = AsyncStream { [weak self] continuation in
        guard let self else { return }
        self.continuation = continuation
        self.client.registerForNowPlayingNotifications { state in
            continuation.yield(state)
        }
    }

    init(client: MediaRemoteClient) {
        self.client = client
    }

    func play() { client.sendCommand(.play) }
    func pause() { client.sendCommand(.pause) }
    func next() { client.sendCommand(.next) }
    func previous() { client.sendCommand(.previous) }
}
