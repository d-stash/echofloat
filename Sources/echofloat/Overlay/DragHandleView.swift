import SwiftUI
import AppKit

/// Invisible layer that lets the user reposition the borderless overlay panel by
/// dragging anywhere it's placed (typically the pill/panel background, behind any
/// buttons or text so those still receive their own clicks). Persists the resulting
/// offset from the default notch-centered position so it's restored across rebuilds.
struct DragHandleView: NSViewRepresentable {
    let defaultOrigin: (CGSize) -> CGPoint

    func makeNSView(context: Context) -> DragHandleNSView {
        let view = DragHandleNSView()
        view.defaultOrigin = defaultOrigin
        return view
    }

    func updateNSView(_ nsView: DragHandleNSView, context: Context) {
        nsView.defaultOrigin = defaultOrigin
    }
}

final class DragHandleNSView: NSView {
    var defaultOrigin: ((CGSize) -> CGPoint)?

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        window.performDrag(with: event)
        guard let defaultOrigin = defaultOrigin?(window.frame.size) else { return }
        OverlayPlacementStore.positionOffset = CGSize(
            width: window.frame.origin.x - defaultOrigin.x,
            height: window.frame.origin.y - defaultOrigin.y
        )
    }
}
