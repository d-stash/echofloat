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
        for panel in panels.values { panel.orderOut(nil) }
        panels.removeAll()
        guard isVisible else { return }

        let targetScreens = showOnAllDisplays ? NSScreen.screens : NSScreen.main.map { [$0] } ?? []
        let minSize = defaultSize
        let baseSize = OverlayPlacementStore.customSize ?? defaultSize
        let size = CGSize(width: max(baseSize.width, minSize.width), height: max(baseSize.height, minSize.height))
        let positionOffset = OverlayPlacementStore.positionOffset

        for screen in targetScreens {
            let metrics = ScreenMetrics(screen: screen)
            let defaultFrame = NotchGeometry.overlayFrame(for: metrics, collapsedSize: size)
            let offsetFrame = defaultFrame.offsetBy(dx: positionOffset.width, dy: positionOffset.height)
            // Keep the (possibly user-dragged) frame at least partially on this screen so a
            // stale/odd stored offset can never make the whole overlay vanish off-screen.
            let frame = Self.clamp(offsetFrame, toFit: screen.frame)
            let defaultOrigin = { frame.origin }

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

            let hosting = NSHostingView(rootView: OverlayContentView(
                viewModel: viewModel,
                theme: themeManager.current,
                minSize: minSize,
                defaultOrigin: defaultOrigin
            ))
            hosting.autoresizingMask = [.width, .height]
            hosting.frame = NSRect(origin: .zero, size: frame.size)
            panel.contentView = hosting
            panel.orderFrontRegardless()

            panels[ObjectIdentifier(screen)] = panel
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

            ResizeHandleView(axis: .horizontal, minSize: minSize, defaultOrigin: defaultOrigin)
                .frame(width: resizeHandleThickness)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .trailing)
            ResizeHandleView(axis: .vertical, minSize: minSize, defaultOrigin: defaultOrigin)
                .frame(height: resizeHandleThickness)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .bottom)
            ResizeHandleView(axis: .both, minSize: minSize, defaultOrigin: defaultOrigin)
                .frame(width: 14, height: 14)
        }
    }
}
