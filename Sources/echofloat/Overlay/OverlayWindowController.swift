import AppKit
import Combine
import SwiftUI

@MainActor
private final class OverlayInteractionModel: ObservableObject {
    @Published var isExpanded = false
}

@MainActor
final class OverlayWindowController: NSObject {
    private var panels: [ObjectIdentifier: NSPanel] = [:]
    private var interactionModels: [ObjectIdentifier: OverlayInteractionModel] = [:]
    private var themeSubscription: AnyCancellable?
    private var mouseMonitor: Any?
    private let viewModel: PlayerViewModel
    private let themeManager: ThemeManager
    private let defaults: UserDefaults
    private static let visibilityKey = "echofloat.overlayVisible"

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
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in self?.handleGlobalMouseMove() }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildPanels),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        rebuildPanels()
    }

    @objc private func rebuildPanels() {
        for panel in panels.values { panel.orderOut(nil) }
        panels.removeAll()
        interactionModels.removeAll()
        guard isVisible else { return }

        let targetScreens = showOnAllDisplays ? NSScreen.screens : NSScreen.main.map { [$0] } ?? []
        let collapsedSize = CGSize(width: 220, height: 32)
        let expandedSize = CGSize(width: 360, height: 360)

        for screen in targetScreens {
            let metrics = ScreenMetrics(screen: screen)
            let frame = NotchGeometry.overlayFrame(for: metrics, collapsedSize: expandedSize)
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
            panel.acceptsMouseMovedEvents = true

            let model = OverlayInteractionModel()
            let hosting = NSHostingView(rootView: OverlayContentView(
                viewModel: viewModel,
                model: model,
                theme: themeManager.current,
                collapsedSize: collapsedSize
            ))
            hosting.frame = NSRect(origin: .zero, size: frame.size)
            panel.contentView = hosting
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()

            let id = ObjectIdentifier(screen)
            panels[id] = panel
            interactionModels[id] = model
        }
    }

    private func handleGlobalMouseMove() {
        guard isVisible else { return }
        let location = NSEvent.mouseLocation
        for (id, panel) in panels where panel.frame.contains(location) {
            if panel.ignoresMouseEvents {
                panel.ignoresMouseEvents = false
                interactionModels[id]?.isExpanded = true
            }
        }
    }
}

private struct OverlayContentView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var model: OverlayInteractionModel
    let theme: Theme
    let collapsedSize: CGSize

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            CollapsedPillView(viewModel: viewModel, theme: theme, onHoverChanged: setExpanded)
                .frame(width: collapsedSize.width, height: collapsedSize.height)
            if model.isExpanded {
                ExpandedLyricsPanelView(viewModel: viewModel, theme: theme, onHoverChanged: setExpanded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .onHover(perform: setExpanded)
    }

    private func setExpanded(_ expanded: Bool) {
        model.isExpanded = expanded
    }
}
