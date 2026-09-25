import Sparkle

/// Thin seam over Sparkle's updater so menu-bar wiring can be unit tested
/// without a real Sparkle instance (which needs a signed appcast feed and
/// network access). Mirrors the `LoginItemServicing` pattern already used
/// for `AutostartManager`.
protocol UpdateChecking: AnyObject {
    func checkForUpdates(_ sender: Any?)
    var automaticallyChecksForUpdates: Bool { get set }
}

extension SPUStandardUpdaterController: @preconcurrency UpdateChecking {
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }
}

/// Default used by call sites (and most existing tests) that don't care
/// about update checking, so adding this dependency doesn't force every
/// `StatusItemController` construction site to supply a real updater.
final class NoopUpdateChecker: UpdateChecking {
    var automaticallyChecksForUpdates = false
    func checkForUpdates(_ sender: Any?) {}
}
