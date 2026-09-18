import Combine
import Foundation

final class ThemeManager: ObservableObject {
    @Published private(set) var current: Theme

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
