import AppKit

/// Maps a `NowPlayingState.sourceAppName` to the bundle identifier of the app
/// that should be fronted when the overlay is clicked. Nil for an unknown source.
func sourceAppBundleID(for name: String) -> String? {
    switch name {
    case "Music": return "com.apple.Music"
    case "Spotify": return "com.spotify.client"
    case "YouTube Music": return "com.google.Chrome"
    default: return nil
    }
}

/// Brings an application to the foreground. Abstracted behind a protocol so the
/// view model can be tested without launching real apps.
protocol AppActivating {
    func activate(bundleID: String)
}

/// Default `AppActivating` backed by `NSWorkspace`. Launches the app if needed
/// and activates it. Requires no Automation (TCC) permission.
struct NSWorkspaceAppActivator: AppActivating {
    func activate(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSLog("Echofloat: no application found for bundle id \(bundleID)")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("Echofloat: failed to activate \(bundleID): \(error.localizedDescription)")
            }
        }
    }
}
