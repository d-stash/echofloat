import Foundation

protocol MusicSource {
    var nowPlayingUpdates: AsyncStream<NowPlayingState?> { get }
    func play()
    func pause()
    func next()
    func previous()
}
