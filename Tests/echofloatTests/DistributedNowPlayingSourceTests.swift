import Foundation
import Testing
@testable import echofloat

@MainActor
private final class FakeAppleScriptExecutor: AppleScriptExecuting {
    var outputs: [String: String] = [:]
    var suspendPositionQueries = false
    private(set) var runScripts: [String] = []
    private(set) var commandScripts: [String] = []
    private(set) var positionQueryStarted = false
    private var positionContinuation: CheckedContinuation<String?, Never>?

    func run(_ script: String) async throws -> String? {
        runScripts.append(script)
        if script.contains("player position"), suspendPositionQueries {
            positionQueryStarted = true
            return await withCheckedContinuation { continuation in
                positionContinuation = continuation
            }
        }
        if script.contains("application \"Music\"") {
            return outputs["Music"]
        }
        if script.contains("application \"Spotify\"") {
            return outputs["Spotify"]
        }
        return nil
    }

    func fireAndForget(_ script: String) {
        commandScripts.append(script)
    }

    func completePositionQuery(with output: String?) {
        positionContinuation?.resume(returning: output)
        positionContinuation = nil
    }
}

private func notification(
    title: String,
    state: String,
    artist: String = "Artist"
) -> [AnyHashable: Any] {
    [
        "Name": title,
        "Artist": artist,
        "Album": "Album",
        "Duration": 180_000.0,
        "Player State": state,
    ]
}

@Test @MainActor func loadsInitialSnapshotsForMusicAndSpotify() async throws {
    let executor = FakeAppleScriptExecutor()
    executor.outputs["Music"] = DistributedNowPlayingSource.snapshotOutput(
        title: "Already Playing",
        artist: "Artist",
        album: "Album",
        duration: 180,
        state: "playing",
        position: 12
    )
    executor.outputs["Spotify"] = nil
    let source = DistributedNowPlayingSource(
        scriptExecutor: executor,
        notificationCenter: nil,
        positionPollIntervalNanoseconds: nil
    )

    var iterator = source.nowPlayingUpdates.makeAsyncIterator()
    let yielded = try #require(await iterator.next())
    let state = try #require(yielded)

    #expect(state.track.title == "Already Playing")
    #expect(state.sourceAppName == "Music")
    #expect(state.elapsedSeconds == 12)
    #expect(executor.runScripts.contains { $0.contains("application \"Music\"") })
    #expect(executor.runScripts.contains { $0.contains("application \"Spotify\"") })
}

@Test @MainActor func pausedNotificationDoesNotReplaceOtherPlayingPlayer() async {
    let executor = FakeAppleScriptExecutor()
    let source = DistributedNowPlayingSource(
        scriptExecutor: executor,
        notificationCenter: nil,
        positionPollIntervalNanoseconds: nil,
        loadsInitialSnapshots: false
    )
    var iterator = source.nowPlayingUpdates.makeAsyncIterator()

    source.receive(notification(title: "Music Song", state: "Playing"), appName: "Music")
    _ = await iterator.next()
    source.receive(notification(title: "Spotify Song", state: "Paused"), appName: "Spotify")

    source.next()

    #expect(executor.commandScripts.last == #"tell application "Music" to next track"#)
}

@Test @MainActor func mostRecentlyPlayingPlayerWinsAndReceivesCommands() async throws {
    let executor = FakeAppleScriptExecutor()
    let source = DistributedNowPlayingSource(
        scriptExecutor: executor,
        notificationCenter: nil,
        positionPollIntervalNanoseconds: nil,
        loadsInitialSnapshots: false
    )
    var iterator = source.nowPlayingUpdates.makeAsyncIterator()

    source.receive(notification(title: "Music Song", state: "Playing"), appName: "Music")
    _ = await iterator.next()
    source.receive(notification(title: "Spotify Song", state: "Playing"), appName: "Spotify")
    let yielded = try #require(await iterator.next())
    let selected = try #require(yielded)
    source.pause()

    #expect(selected.sourceAppName == "Spotify")
    #expect(executor.commandScripts.last == #"tell application "Spotify" to pause"#)
}

@Test @MainActor func pausedFallbackIsDeterministicBeforeAnyPlayerWasActive() async throws {
    let source = DistributedNowPlayingSource(
        scriptExecutor: FakeAppleScriptExecutor(),
        notificationCenter: nil,
        positionPollIntervalNanoseconds: nil,
        loadsInitialSnapshots: false
    )
    var iterator = source.nowPlayingUpdates.makeAsyncIterator()

    source.receive(notification(title: "Spotify Song", state: "Paused"), appName: "Spotify")
    _ = await iterator.next()
    source.receive(notification(title: "Music Song", state: "Paused"), appName: "Music")
    let yielded = try #require(await iterator.next())
    let selected = try #require(yielded)

    #expect(selected.sourceAppName == "Music")
}

@Test @MainActor func stalePositionQueryDoesNotOverwriteNewerTrack() async {
    let executor = FakeAppleScriptExecutor()
    executor.suspendPositionQueries = true
    let source = DistributedNowPlayingSource(
        scriptExecutor: executor,
        notificationCenter: nil,
        positionPollIntervalNanoseconds: 1_000_000,
        loadsInitialSnapshots: false
    )
    var received: [NowPlayingState?] = []
    let collector = Task { @MainActor in
        for await state in source.nowPlayingUpdates {
            received.append(state)
        }
    }
    await Task.yield()

    source.receive(notification(title: "Old Song", state: "Playing"), appName: "Music")
    for _ in 0..<100 where !executor.positionQueryStarted {
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    #expect(executor.positionQueryStarted)

    source.receive(notification(title: "New Song", state: "Playing"), appName: "Music")
    executor.suspendPositionQueries = false
    executor.completePositionQuery(with: "42")
    try? await Task.sleep(nanoseconds: 20_000_000)
    collector.cancel()
    await collector.value

    let titles = received.compactMap { $0?.track.title }
    #expect(titles == ["Old Song", "New Song"])
}
