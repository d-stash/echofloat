import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var overlayController: OverlayWindowController?
    private var viewModel: PlayerViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let mediaRemoteClient = LiveMediaRemoteClient() else {
            NSLog("Echofloat: MediaRemote framework unavailable; now-playing detection disabled")
            return
        }

        let musicSource = SystemNowPlayingSource(client: mediaRemoteClient)
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
        statusItemController = StatusItemController(
            themeManager: themeManager,
            overlayController: overlay,
            autostartManager: autostartManager
        )
    }
}
