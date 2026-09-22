import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var overlayController: OverlayWindowController?
    private var viewModel: PlayerViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // MediaRemote (private framework) is locked to Apple-signed processes only as of
        // macOS Sonoma 15.3+, so third-party detection now goes through public Distributed
        // Notifications (Music.app, Spotify) plus AppleScript/JS tab scraping (YouTube Music).
        let musicSource = CompositeNowPlayingSource(sources: [
            DistributedNowPlayingSource(),
            BrowserNowPlayingSource()
        ])
        let cacheDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Echofloat/LyricsCache", isDirectory: true)
        let cache = LyricsCache(directory: cacheDirectory)
        let lyricsProvider = LRCLibProvider()

        let vm = PlayerViewModel(musicSource: musicSource, lyricsProvider: lyricsProvider, cache: cache)
        vm.start()
        viewModel = vm

        let themeManager = ThemeManager()
        let overlay = OverlayWindowController(viewModel: vm, themeManager: themeManager)
        overlay.start()
        overlayController = overlay

        let autostartManager = AutostartManager()
        do {
            try autostartManager.removeLegacyLaunchAgent()
        } catch {
            NSLog("Echofloat: Could not remove legacy login item: \(error.localizedDescription)")
        }
        statusItemController = StatusItemController(
            themeManager: themeManager,
            overlayController: overlay,
            autostartManager: autostartManager
        )
    }
}
