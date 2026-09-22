import Foundation

enum AppCommand {
    static func run(arguments: [String], autostartManager: AutostartManager) -> Int32? {
        guard arguments.dropFirst().first == "--unregister-login-item" else {
            return nil
        }

        do {
            try autostartManager.unregisterIfRegistered()
            print("Echofloat Launch at Login registration removed.")
            return 0
        } catch {
            FileHandle.standardError.write(
                Data("Could not remove Echofloat Launch at Login registration: \(error.localizedDescription)\n".utf8)
            )
            return 1
        }
    }
}
