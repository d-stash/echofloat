import SwiftUI
import AppKit

/// Which dimensions a resize handle affects, matching a normal window's edge/corner
/// resize regions (right edge = horizontal only, bottom edge = vertical only,
/// bottom-right corner = both).
enum ResizeAxis {
    case horizontal
    case vertical
    case both
}

/// Standard window-style resize handle: always active (no hover/expand gating),
/// placed along an edge or corner. Keeps the panel's top edge and horizontal
/// center fixed while resizing, and never shrinks below `minSize` (the widget's
/// default size), matching "keep current width as minimum width".
struct ResizeHandleView: NSViewRepresentable {
    let axis: ResizeAxis
    let minSize: CGSize
    let defaultOrigin: (CGSize) -> CGPoint

    func makeNSView(context: Context) -> ResizeHandleNSView {
        let view = ResizeHandleNSView()
        view.axis = axis
        view.minSize = minSize
        view.defaultOrigin = defaultOrigin
        return view
    }

    func updateNSView(_ nsView: ResizeHandleNSView, context: Context) {
        nsView.axis = axis
        nsView.minSize = minSize
        nsView.defaultOrigin = defaultOrigin
    }
}

final class ResizeHandleNSView: NSView {
    var axis: ResizeAxis = .both
    var minSize: CGSize = CGSize(width: 260, height: 90)
    var defaultOrigin: ((CGSize) -> CGPoint)?

    private var startFrame: CGRect = .zero
    private var startMouse: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - startMouse.x
        let dy = current.y - startMouse.y

        var newWidth = startFrame.width
        var newHeight = startFrame.height
        if axis == .horizontal || axis == .both {
            newWidth = max(minSize.width, startFrame.width + dx)
        }
        if axis == .vertical || axis == .both {
            // Screen coordinates have origin at bottom-left, so dragging down
            // (negative dy) should grow height while keeping the top fixed.
            newHeight = max(minSize.height, startFrame.height - dy)
        }
        let newOriginX = startFrame.midX - newWidth / 2
        let newOriginY = startFrame.maxY - newHeight

        window.setFrame(CGRect(x: newOriginX, y: newOriginY, width: newWidth, height: newHeight), display: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard let window else { return }
        let newSize = window.frame.size
        OverlayPlacementStore.customSize = newSize
        if let defaultOrigin = defaultOrigin?(newSize) {
            OverlayPlacementStore.positionOffset = CGSize(
                width: window.frame.origin.x - defaultOrigin.x,
                height: window.frame.origin.y - defaultOrigin.y
            )
        }
    }
}
