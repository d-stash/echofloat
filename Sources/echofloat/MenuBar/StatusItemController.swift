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

        let autostartItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleAutostart), keyEquivalent: "")
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

    @objc private func toggleAutostart() {
        autostartManager.isEnabled.toggle()
        buildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
