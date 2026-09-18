import Foundation
import Testing
@testable import echofloat

@Test func exposesExactlyTwoBuiltInThemes() {
    #expect(Theme.builtIn.count == 2)
    #expect(Theme.builtIn.map(\.id) == ["aurora-glass", "neon-arcade"])
}

@Test func defaultsToAuroraGlassWhenNothingPersisted() {
    let defaults = UserDefaults(suiteName: "echofloat-tests-\(UUID().uuidString)")!
    let manager = ThemeManager(defaults: defaults)
    #expect(manager.current.id == "aurora-glass")
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
