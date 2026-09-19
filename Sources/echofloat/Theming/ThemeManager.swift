import Combine
import Foundation

final class ThemeManager: ObservableObject {
    // Not @Published: that wrapper fires objectWillChange *before* mutating the
    // value, so any subscriber that reads `current` synchronously inside its
    // sink (e.g. OverlayWindowController rebuilding panels) would see the
    // previous theme, one step behind every selection. Notifying manually
    // after the assignment guarantees subscribers see the new value.
    private(set) var current: Theme {
        didSet { objectWillChange.send() }
    }

    private let defaults: UserDefaults
    private static let key = "echofloat.selectedThemeID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedID = defaults.string(forKey: Self.key)
        self.current = Theme.builtIn.first { $0.id == savedID } ?? .auroraGlass
    }

    func select(_ theme: Theme) {
        current = theme
        defaults.set(theme.id, forKey: Self.key)
    }
}
