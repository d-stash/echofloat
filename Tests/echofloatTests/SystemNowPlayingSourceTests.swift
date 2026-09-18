import Foundation
import Testing
@testable import echofloat

private final class FakeMediaRemoteClient: MediaRemoteClient {
    var registeredHandler: ((NowPlayingState?) -> Void)?
    private(set) var sentCommands: [MediaRemoteCommand] = []

    func registerForNowPlayingNotifications(handler: @escaping (NowPlayingState?) -> Void) {
        registeredHandler = handler
    }

    func sendCommand(_ command: MediaRemoteCommand) {
        sentCommands.append(command)
    }
}

@Test func forwardsMediaRemoteUpdatesThroughAsyncStream() async {
    let client = FakeMediaRemoteClient()
    let source = SystemNowPlayingSource(client: client)

    var iterator = source.nowPlayingUpdates.makeAsyncIterator()
    let track = TrackSignature(title: "T", artist: "A", album: nil, durationSeconds: nil)
    let state = NowPlayingState(track: track, sourceAppName: "System", status: .playing, elapsedSeconds: 0, capturedAt: Date())

    let task = Task { await iterator.next() }
    try? await Task.sleep(nanoseconds: 10_000_000)
    client.registeredHandler?(state)

    let received = await task.value
    #expect(received == state)
}

@Test func forwardsCommandsToClient() {
    let client = FakeMediaRemoteClient()
    let source = SystemNowPlayingSource(client: client)
    source.play()
    source.pause()
    source.next()
    source.previous()
    #expect(client.sentCommands == [.play, .pause, .next, .previous])
}
