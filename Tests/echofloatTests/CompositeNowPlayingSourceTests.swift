import Foundation
import Testing
@testable import echofloat

@MainActor
private final class ControllableMusicSource: MusicSource {
    private let stream: AsyncStream<NowPlayingState?>
    private let continuation: AsyncStream<NowPlayingState?>.Continuation
    private(set) var commands: [String] = []

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    var nowPlayingUpdates: AsyncStream<NowPlayingState?> { stream }
    func send(_ state: NowPlayingState?) { continuation.yield(state) }
    func play() { commands.append("play") }
    func pause() { commands.append("pause") }
    func next() { commands.append("next") }
    func previous() { commands.append("previous") }
}

private func playingState(_ title: String, source: String) -> NowPlayingState {
    NowPlayingState(
        track: TrackSignature(title: title, artist: "Artist", album: nil, durationSeconds: nil),
        sourceAppName: source,
        status: .playing,
        elapsedSeconds: 0,
        capturedAt: Date()
    )
}

@Test @MainActor func concurrentSourceUpdatesRemainIsolatedAndRouteToLatestPlayingSource() async throws {
    let first = ControllableMusicSource()
    let second = ControllableMusicSource()
    let composite = CompositeNowPlayingSource(sources: [first, second])
    var iterator = composite.nowPlayingUpdates.makeAsyncIterator()

    first.send(playingState("First", source: "First"))
    _ = await iterator.next()
    second.send(playingState("Second", source: "Second"))
    let yielded = try #require(await iterator.next())
    let selected = try #require(yielded)
    composite.next()

    #expect(selected.sourceAppName == "Second")
    #expect(first.commands.isEmpty)
    #expect(second.commands == ["next"])
}

@Test @MainActor func simultaneousSourceTasksAreSerialized() async throws {
    let first = ControllableMusicSource()
    let second = ControllableMusicSource()
    let composite = CompositeNowPlayingSource(sources: [first, second])
    var iterator = composite.nowPlayingUpdates.makeAsyncIterator()
    let firstState = playingState("First", source: "First")
    let secondState = playingState("Second", source: "Second")

    let firstTask = Task.detached { await first.send(firstState) }
    let secondTask = Task.detached { await second.send(secondState) }
    await firstTask.value
    await secondTask.value

    let firstEvent = try #require(await iterator.next())
    let secondEvent = try #require(await iterator.next())
    let firstYield = try #require(firstEvent)
    let secondYield = try #require(secondEvent)

    #expect(Set([firstYield.sourceAppName, secondYield.sourceAppName]) == Set(["First", "Second"]))
}
