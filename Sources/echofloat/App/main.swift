import AppKit

if let exitCode = AppCommand.run(
    arguments: CommandLine.arguments,
    autostartManager: AutostartManager()
) {
    exit(exitCode)
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
