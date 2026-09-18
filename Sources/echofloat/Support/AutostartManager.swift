import Foundation

final class AutostartManager {
    private let label = "com.echofloat.autostart"
    private let launchAgentsDirectory: URL
    private let fileManager: FileManager
    private let executablePath: () -> String

    init(
        launchAgentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents"),
        fileManager: FileManager = .default,
        executablePath: @escaping () -> String = { Bundle.main.executablePath ?? "" }
    ) {
        self.launchAgentsDirectory = launchAgentsDirectory
        self.fileManager = fileManager
        self.executablePath = executablePath
    }

    private var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    var isEnabled: Bool {
        get { fileManager.fileExists(atPath: plistURL.path) }
        set {
            if newValue {
                write()
            } else {
                remove()
            }
        }
    }

    func plistContents() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath())</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }

    private func write() {
        try? fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
        try? plistContents().write(to: plistURL, atomically: true, encoding: .utf8)
    }

    private func remove() {
        try? fileManager.removeItem(at: plistURL)
    }
}
