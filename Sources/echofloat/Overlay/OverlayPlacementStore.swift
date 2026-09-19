import Foundation
import CoreGraphics

/// Persists user-customized overlay position/size across launches and panel rebuilds
/// (rebuilds happen on theme change, display change, and visibility toggle).
///
/// Position is stored as an offset from the default notch-centered frame, not an
/// absolute origin, so it still lines up sensibly if screen resolution changes.
/// Size is stored as an absolute width/height for the expanded panel; callers are
/// responsible for clamping it to a minimum width (the collapsed pill's width).
enum OverlayPlacementStore {
    private static let offsetKey = "echofloat.overlayPositionOffset"
    private static let sizeKey = "echofloat.overlaySize"

    static var positionOffset: CGSize {
        get {
            guard let dict = UserDefaults.standard.dictionary(forKey: offsetKey),
                  let dx = dict["dx"] as? Double, let dy = dict["dy"] as? Double else { return .zero }
            return CGSize(width: dx, height: dy)
        }
        set {
            UserDefaults.standard.set(["dx": newValue.width, "dy": newValue.height], forKey: offsetKey)
        }
    }

    static var customSize: CGSize? {
        get {
            guard let dict = UserDefaults.standard.dictionary(forKey: sizeKey),
                  let w = dict["w"] as? Double, let h = dict["h"] as? Double else { return nil }
            return CGSize(width: w, height: h)
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: sizeKey)
                return
            }
            UserDefaults.standard.set(["w": newValue.width, "h": newValue.height], forKey: sizeKey)
        }
    }
}
