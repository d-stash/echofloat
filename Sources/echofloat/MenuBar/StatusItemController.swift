import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let themeManager: ThemeManager
    private let overlayController: OverlayWindowController
    private let autostartManager: AutostartManager
    private let menu = NSMenu()
    private let visibilityItem = NSMenuItem(title: "", action: #selector(toggleOverlayVisibility), keyEquivalent: "")
    private let themeMenu = NSMenu()
    private let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
    private let displayModeItem = NSMenuItem(title: "Show on Active Display Only", action: #selector(toggleDisplayMode), keyEquivalent: "")
    private let autostartItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleAutostart), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit Echofloat", action: #selector(quit), keyEquivalent: "q")

    init(
        themeManager: ThemeManager,
        overlayController: OverlayWindowController,
        autostartManager: AutostartManager
    ) {
        self.themeManager = themeManager
        self.overlayController = overlayController
        self.autostartManager = autostartManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Echofloat")
        configureMenu()
        refreshMenuState()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureMenu() {
        menu.delegate = self

        visibilityItem.target = self
        menu.addItem(visibilityItem)

        for theme in Theme.builtIn {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.id
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        displayModeItem.target = self
        menu.addItem(displayModeItem)

        autostartItem.target = self
        menu.addItem(autostartItem)

        menu.addItem(.separator())

        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refreshMenuState() {
        visibilityItem.title = overlayController.isVisible ? "Hide Overlay" : "Show Overlay"
        displayModeItem.state = overlayController.showOnAllDisplays ? .off : .on
        autostartItem.title = autostartManager.status == .requiresApproval
            ? "Launch at Login (Approval Required)"
            : "Launch at Login"
        autostartItem.state = autostartManager.isEnabled ? .on : .off

        for item in themeMenu.items {
            guard let id = item.representedObject as? String else { continue }
            item.state = id == themeManager.current.id ? .on : .off
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenuState()
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let theme = Theme.builtIn.first(where: { $0.id == id }) else { return }
        themeManager.select(theme)
        refreshMenuState()
    }

    @objc private func toggleDisplayMode() {
        overlayController.showOnAllDisplays.toggle()
        refreshMenuState()
    }

    @objc private func toggleOverlayVisibility() {
        overlayController.isVisible.toggle()
        refreshMenuState()
    }

    @objc private func toggleAutostart() {
        do {
            try autostartManager.setEnabled(!autostartManager.isEnabled)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn’t update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSLog("Echofloat: Launch at Login failed: \(error.localizedDescription)")
        }
        refreshMenuState()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
