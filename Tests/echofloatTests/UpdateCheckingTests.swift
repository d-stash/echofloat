import Testing
@testable import echofloat

private final class RecordingUpdateChecker: UpdateChecking {
    var automaticallyChecksForUpdates = true
    var checkForUpdatesCallCount = 0

    func checkForUpdates(_ sender: Any?) {
        checkForUpdatesCallCount += 1
    }
}

@Test func recordingCheckerCountsInvocations() {
    let checker = RecordingUpdateChecker()
    checker.checkForUpdates(nil)
    checker.checkForUpdates(nil)
    #expect(checker.checkForUpdatesCallCount == 2)
}

@Test func noopUpdateCheckerIsInertAndDoesNotCrash() {
    let checker = NoopUpdateChecker()
    checker.checkForUpdates(nil)
    checker.automaticallyChecksForUpdates = false
    #expect(checker.automaticallyChecksForUpdates == false)
}
