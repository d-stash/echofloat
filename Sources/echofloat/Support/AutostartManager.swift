import Foundation

final class AutostartManager {
    private let service: LoginItemServicing
    private let fileManager: FileManager
    private let legacyPlistURL: URL

    init(
        service: LoginItemServicing = MainAppLoginItemService(),
        legacyLaunchAgentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents"),
        fileManager: FileManager = .default
    ) {
        self.service = service
        self.fileManager = fileManager
        legacyPlistURL = legacyLaunchAgentsDirectory
            .appendingPathComponent("com.echofloat.autostart.plist")
    }

    var status: LoginItemStatus { service.status }
    var isEnabled: Bool { status == .enabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    func removeLegacyLaunchAgent() throws {
        guard fileManager.fileExists(atPath: legacyPlistURL.path) else { return }
        try fileManager.removeItem(at: legacyPlistURL)
    }
}
