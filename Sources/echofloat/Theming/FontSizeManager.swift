import Combine
import Foundation

/// Overlay text scale, independent of Theme. Presets multiply the base point
/// sizes used throughout the overlay (see `MiniPlayerBarView`) so users can
/// bump legibility up or down without a whole new theme.
enum FontSizePreset: String, CaseIterable, Identifiable {
    case small
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    var name: String {
        switch self {
        case .small: return "Small"
        case .standard: return "Default"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// Multiplier applied to each base point size in the overlay.
    var scale: CGFloat {
        switch self {
        case .small: return 0.85
        case .standard: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }

    /// Ordered smallest to largest so increase/decrease can step through them.
    static let ordered: [FontSizePreset] = [.small, .standard, .large, .extraLarge]
}

final class FontSizeManager: ObservableObject {
    @Published private(set) var current: FontSizePreset

    private let defaults: UserDefaults
    private static let key = "echofloat.fontSizePresetID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedID = defaults.string(forKey: Self.key)
        self.current = savedID.flatMap(FontSizePreset.init(rawValue:)) ?? .standard
    }

    func select(_ preset: FontSizePreset) {
        current = preset
        defaults.set(preset.rawValue, forKey: Self.key)
    }

    /// Steps to the next larger preset; no-ops once already at the largest.
    func increase() {
        guard let index = FontSizePreset.ordered.firstIndex(of: current),
              index < FontSizePreset.ordered.count - 1 else { return }
        select(FontSizePreset.ordered[index + 1])
    }

    /// Steps to the next smaller preset; no-ops once already at the smallest.
    func decrease() {
        guard let index = FontSizePreset.ordered.firstIndex(of: current),
              index > 0 else { return }
        select(FontSizePreset.ordered[index - 1])
    }

    func reset() {
        select(.standard)
    }
}
