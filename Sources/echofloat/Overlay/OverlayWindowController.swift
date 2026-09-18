import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController: NSObject {
    private var panels: [ObjectIdentifier: NSPanel] = [:]
    private let viewModel: PlayerViewModel
    private let themeManager: ThemeManager
    var showOnAllDisplays = true {
        didSet { rebuildPanels() }
    }

    init(viewModel: PlayerViewModel, themeManager: ThemeManager) {
        self.viewModel = viewModel
        self.themeManager = themeManager
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildPanels),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func start() {
        rebuildPanels()
    }

    @objc private func rebuildPanels() {
        for panel in panels.values { panel.orderOut(nil) }
        panels.removeAll()

        let targetScreens = showOnAllDisplays ? NSScreen.screens : NSScreen.main.map { [$0] } ?? []
        let collapsedSize = CGSize(width: 220, height: 32)

        for screen in targetScreens {
            let metrics = ScreenMetrics(screen: screen)
            let frame = NotchGeometry.overlayFrame(for: metrics, collapsedSize: collapsedSize)

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
            panel.ignoresMouseEvents = true

            let hosting = NSHostingView(
                rootView: CollapsedPillView(viewModel: viewModel, theme: themeManager.current)
            )
            hosting.frame = NSRect(origin: .zero, size: frame.size)
            panel.contentView = hosting
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()

            panels[ObjectIdentifier(screen)] = panel
        }
    }
}
