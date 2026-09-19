import AppKit

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let themeManager: ThemeManager
    private let overlayController: OverlayWindowController
    private let autostartManager: AutostartManager

    init(
        themeManager: ThemeManager,
        overlayController: OverlayWindowController,
        autostartManager: AutostartManager
    ) {
        self.themeManager = themeManager
        self.overlayController = overlayController
        self.autostartManager = autostartManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Echofloat")
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let visibilityItem = NSMenuItem(
            title: overlayController.isVisible ? "Hide Overlay" : "Show Overlay",
            action: #selector(toggleOverlayVisibility),
            keyEquivalent: ""
        )
        visibilityItem.target = self
        menu.addItem(visibilityItem)

        let themeMenu = NSMenu()
        for theme in Theme.builtIn {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.id
            item.state = theme.id == themeManager.current.id ? .on : .off
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let displayModeItem = NSMenuItem(
            title: "Show on Active Display Only",
            action: #selector(toggleDisplayMode),
            keyEquivalent: ""
        )
        displayModeItem.target = self
        displayModeItem.state = overlayController.showOnAllDisplays ? .off : .on
        menu.addItem(displayModeItem)

        let autostartTitle =
            autostartManager.status == .requiresApproval
            ? "Launch at Login (Approval Required)"
            : "Launch at Login"
        let autostartItem = NSMenuItem(title: autostartTitle, action: #selector(toggleAutostart), keyEquivalent: "")
        autostartItem.target = self
        autostartItem.state = autostartManager.isEnabled ? .on : .off
        menu.addItem(autostartItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Echofloat", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let theme = Theme.builtIn.first(where: { $0.id == id }) else { return }
        themeManager.select(theme)
        buildMenu()
    }

    @objc private func toggleDisplayMode() {
        overlayController.showOnAllDisplays.toggle()
        buildMenu()
    }

    @objc private func toggleOverlayVisibility() {
        overlayController.isVisible.toggle()
        buildMenu()
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
        buildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
