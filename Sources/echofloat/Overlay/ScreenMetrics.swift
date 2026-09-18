import Foundation
import AppKit

struct ScreenMetrics: Equatable {
    let frame: CGRect
    let notchLeftMaxX: CGFloat?
    let notchRightMinX: CGFloat?
}

extension ScreenMetrics {
    init(screen: NSScreen) {
        frame = screen.frame
        notchLeftMaxX = screen.auxiliaryTopLeftArea.map { $0.maxX }
        notchRightMinX = screen.auxiliaryTopRightArea.map { $0.minX }
    }
}
