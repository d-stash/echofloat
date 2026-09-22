import Foundation

@MainActor
protocol AppleScriptExecuting {
    func run(_ script: String) async throws -> String?
    func fireAndForget(_ script: String)
}

@MainActor
struct LiveAppleScriptExecutor: AppleScriptExecuting {
    nonisolated init() {}

    func run(_ script: String) async throws -> String? {
        try await AppleScriptRunner.run(script)
    }

    func fireAndForget(_ script: String) {
        AppleScriptRunner.fireAndForget(script)
    }
}

/// Runs AppleScript via `/usr/bin/osascript`. Used instead of the private
/// MediaRemote API, which macOS Sonoma 15.3+ restricts to Apple-signed
/// processes only. AppleScript/Apple Events are the public, still-working
/// path for talking to Music.app, Spotify, and browsers.
@MainActor
enum AppleScriptRunner {
    /// Runs `script` and returns trimmed stdout, or nil on error/no output.
    static func run(_ script: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            process.terminationHandler = { proc in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (text?.isEmpty ?? true) ? nil : text)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Runs `script` without waiting for a result; failures (e.g. app not
    /// running, Automation permission not yet granted) are logged and ignored.
    static func fireAndForget(_ script: String) {
        Task {
            do {
                _ = try await run(script)
            } catch {
                NSLog("Echofloat: AppleScript command failed: \(error.localizedDescription)")
            }
        }
    }
}
