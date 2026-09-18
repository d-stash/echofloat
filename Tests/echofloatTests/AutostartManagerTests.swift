import Foundation
import Testing
@testable import echofloat

private func makeManager(in directory: URL) -> AutostartManager {
    AutostartManager(launchAgentsDirectory: directory, executablePath: { "/usr/local/bin/echofloat" })
}

@Test func startsDisabledWhenNoPlistExists() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let manager = makeManager(in: dir)
    #expect(manager.isEnabled == false)
}

@Test func enablingWritesPlistWithExecutablePath() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let manager = makeManager(in: dir)
    manager.isEnabled = true
    #expect(manager.isEnabled == true)

    let plistPath = dir.appendingPathComponent("com.echofloat.autostart.plist")
    let contents = try! String(contentsOf: plistPath, encoding: .utf8)
    #expect(contents.contains("/usr/local/bin/echofloat"))
}

@Test func disablingRemovesPlist() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let manager = makeManager(in: dir)
    manager.isEnabled = true
    manager.isEnabled = false
    #expect(manager.isEnabled == false)
}
