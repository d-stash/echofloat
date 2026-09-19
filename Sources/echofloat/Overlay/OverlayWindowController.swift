import AppKit
import Combine
import SwiftUI

@MainActor
final class OverlayWindowController: NSObject {
    private var panels: [ObjectIdentifier: NSPanel] = [:]
    private var themeSubscription: AnyCancellable?
    private let viewModel: PlayerViewModel
    private let themeManager: ThemeManager
    private let defaults: UserDefaults
    private static let visibilityKey = "echofloat.overlayVisible"

    /// Default (and minimum) widget size: fixed lyrics line + controls row, no
    /// hover-driven expand/collapse. Width can never shrink below this default.
    private let defaultSize = CGSize(width: 260, height: 90)

    var showOnAllDisplays = true {
        didSet { rebuildPanels() }
    }

    var isVisible: Bool {
        didSet {
            defaults.set(isVisible, forKey: Self.visibilityKey)
            rebuildPanels()
        }
    }

    init(viewModel: PlayerViewModel, themeManager: ThemeManager, defaults: UserDefaults = .standard) {
        self.viewModel = viewModel
        self.themeManager = themeManager
        self.defaults = defaults
        self.isVisible = defaults.object(forKey: Self.visibilityKey) as? Bool ?? true
        super.init()
        themeSubscription = themeManager.objectWillChange.sink { [weak self] _ in
            self?.rebuildPanels()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildPanels),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        rebuildPanels()
    }

    @objc private func rebuildPanels() {
        guard isVisible else {
            for panel in panels.values { panel.orderOut(nil) }
            panels.removeAll()
            return
        }

        let targetScreens = showOnAllDisplays ? NSScreen.screens : NSScreen.main.map { [$0] } ?? []
        let minSize = defaultSize
        let baseSize = OverlayPlacementStore.customSize ?? defaultSize
        let size = CGSize(width: max(baseSize.width, minSize.width), height: max(baseSize.height, minSize.height))
        let positionOffset = OverlayPlacementStore.positionOffset

        var seenScreens = Set<ObjectIdentifier>()
        for screen in targetScreens {
            let screenID = ObjectIdentifier(screen)
            seenScreens.insert(screenID)

            let metrics = ScreenMetrics(screen: screen)
            let defaultFrame = NotchGeometry.overlayFrame(for: metrics, collapsedSize: size)
            let offsetFrame = defaultFrame.offsetBy(dx: positionOffset.width, dy: positionOffset.height)
            // Keep the (possibly user-dragged) frame at least partially on this screen so a
            // stale/odd stored offset can never make the whole overlay vanish off-screen.
            let frame = Self.clamp(offsetFrame, toFit: screen.frame)
            // Must be the *neutral* (un-offset) origin, not the already-offset `frame`'s
            // origin — otherwise every drag/resize only persists that gesture's delta
            // instead of the true cumulative offset, so any rebuild (theme switch,
            // screen change, visibility toggle) discards prior drags and snaps back.
            let defaultOrigin = { defaultFrame.origin }

            let content = OverlayContentView(
                viewModel: viewModel,
                theme: themeManager.current,
                minSize: minSize,
                defaultOrigin: defaultOrigin
            )

            if let panel = panels[screenID] {
                // Update the existing panel in place — destroying and recreating it on
                // every theme switch/screen change caused a visible flash/pop-in that
                // read as the overlay "snapping back" to its default position, even
                // though the underlying stored offset was already correct.
                (panel.contentView as? NSHostingView<OverlayContentView>)?.rootView = content
                if panel.frame != frame {
                    panel.setFrame(frame, display: true)
                }
            } else {
                let panel = NSPanel(
                    contentRect: frame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.isFloatingPanel = true
                panel.level = .statusBar
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                // The panel's frame always matches its visible content, so it never covers
                // desktop area beyond what's drawn; clicks pass through anywhere else.
                panel.ignoresMouseEvents = false
                panel.acceptsMouseMovedEvents = true

                let hosting = NSHostingView(rootView: content)
                hosting.autoresizingMask = [.width, .height]
                hosting.frame = NSRect(origin: .zero, size: frame.size)
                panel.contentView = hosting
                panel.orderFrontRegardless()

                panels[screenID] = panel
            }
        }

        // Drop panels for screens no longer targeted (showOnAllDisplays toggled off,
        // or a display was disconnected).
        for (screenID, panel) in panels where !seenScreens.contains(screenID) {
            panel.orderOut(nil)
            panels.removeValue(forKey: screenID)
        }
    }

    private static func clamp(_ frame: CGRect, toFit bounds: CGRect) -> CGRect {
        let minVisible: CGFloat = 40 // keep at least this many points on-screen in each axis
        let minX = bounds.minX - frame.width + minVisible
        let maxX = bounds.maxX - minVisible
        let minY = bounds.minY - frame.height + minVisible
        let maxY = bounds.maxY - minVisible
        let x = min(max(frame.origin.x, minX), maxX)
        let y = min(max(frame.origin.y, minY), maxY)
        return CGRect(origin: CGPoint(x: x, y: y), size: frame.size)
    }
}

/// Thin edge/corner strip thickness for the always-on resize handles, matching
/// how normal AppKit windows expose their resize regions.
private let resizeHandleThickness: CGFloat = 6

private struct OverlayContentView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let theme: Theme
    let minSize: CGSize
    let defaultOrigin: () -> CGPoint

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MiniPlayerBarView(viewModel: viewModel, theme: theme, defaultOrigin: defaultOrigin)

            // Real macOS resize cursor can't repaint on a non-activating accessory
            // panel (OS always shows the active app's cursor, by design). Handles
            // stay invisible hit-only regions; user already knows corner is resizable.
            ResizeHandleView(axis: .horizontal, minSize: minSize, defaultOrigin: defaultOrigin)
                .frame(width: resizeHandleThickness)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .trailing)
            ResizeHandleView(axis: .vertical, minSize: minSize, defaultOrigin: defaultOrigin)
                .frame(height: resizeHandleThickness)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .bottom)
            ResizeHandleView(axis: .both, minSize: minSize, defaultOrigin: defaultOrigin)
                .frame(width: 20, height: 20)
        }
    }
}
