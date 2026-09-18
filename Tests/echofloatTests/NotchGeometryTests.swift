import Foundation
import Testing
@testable import echofloat

@Test func centersOnScreenWhenNoNotchPresent() {
    let screen = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1000, height: 700), notchLeftMaxX: nil, notchRightMinX: nil)
    let frame = NotchGeometry.overlayFrame(for: screen, collapsedSize: CGSize(width: 220, height: 32))
    #expect(frame.width == 220)
    #expect(frame.midX == 500)
    #expect(frame.maxY == 700 - 4)
}

@Test func widensToFitNotchWhenPresent() {
    let screen = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1000, height: 700), notchLeftMaxX: 460, notchRightMinX: 540)
    let frame = NotchGeometry.overlayFrame(for: screen, collapsedSize: CGSize(width: 60, height: 32))
    // notch width (80) + 40 padding = 120, wider than the 60pt collapsed size
    #expect(frame.width == 120)
    #expect(frame.midX == 500)
}
