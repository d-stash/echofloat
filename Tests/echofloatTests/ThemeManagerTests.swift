import Foundation
import Testing
@testable import echofloat

@Test func exposesAllBuiltInThemes() {
    #expect(Theme.builtIn.count == 5)
    #expect(Theme.builtIn.map(\.id) == [
        "neon-arcade",
        "retro-terminal",
        "midnight-aurora",
        "sunset-vaporwave",
        "vinyl-warmth",
    ])
}

@Test func defaultsToNeonArcadeWhenNothingPersisted() {
    let defaults = UserDefaults(suiteName: "echofloat-tests-\(UUID().uuidString)")!
    let manager = ThemeManager(defaults: defaults)
    #expect(manager.current.id == "neon-arcade")
}

@Test func selectingThemePersistsAcrossInstances() {
    let suiteName = "echofloat-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let manager = ThemeManager(defaults: defaults)
    manager.select(.neonArcade)
    #expect(manager.current.id == "neon-arcade")

    let reloaded = ThemeManager(defaults: defaults)
    #expect(reloaded.current.id == "neon-arcade")
}
