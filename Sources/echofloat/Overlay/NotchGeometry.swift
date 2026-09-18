import Foundation

enum NotchGeometry {
    static func overlayFrame(for screen: ScreenMetrics, collapsedSize: CGSize) -> CGRect {
        let notchWidth: CGFloat
        if let left = screen.notchLeftMaxX, let right = screen.notchRightMinX, right > left {
            notchWidth = right - left
        } else {
            notchWidth = 0
        }
        let width = max(collapsedSize.width, notchWidth + 40)
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - collapsedSize.height - 4
        return CGRect(x: x, y: y, width: width, height: collapsedSize.height)
    }
}
