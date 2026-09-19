import AppKit
import Foundation
import Testing
@testable import echofloat

private final class MutableLoginItemService: LoginItemServicing {
    var status: LoginItemStatus = .notRegistered
    var statusAfterRegistration: LoginItemStatus = .enabled

    func register() throws {
        status = statusAfterRegistration
    }

    func unregister() throws {
        status = .notRegistered
    }
}

private final class SilentMusicSource: MusicSource {
    var nowPlayingUpdates: AsyncStream<NowPlayingState?> { AsyncStream { _ in } }
    func play() {}
    func pause() {}
    func next() {}
    func previous() {}
}

private struct NeverLyricsProvider: LyricsProvider {
    func lyrics(for track: TrackSignature) async -> LyricsResult { .notFound }
}

private func makeStatusItemTestDirectory() throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let directory = packageRoot
        .appendingPathComponent(".test-artifacts", isDirectory: true)
        .appendingPathComponent("StatusItemControllerTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func reflectedStatusItem(from controller: StatusItemController) -> NSStatusItem? {
    Mirror(reflecting: controller).children
        .first { $0.label == "statusItem" }?
        .value as? NSStatusItem
}

private func autostartMenuItem(in menu: NSMenu) -> NSMenuItem? {
    menu.items.first { $0.title.hasPrefix("Launch at Login") }
}

@Test @MainActor func registrationRequiringApprovalPresentsActionableGuidance() throws {
    let service = MutableLoginItemService()
    service.statusAfterRegistration = .requiresApproval
    let cacheDirectory = try makeStatusItemTestDirectory()
    defer { try? FileManager.default.removeItem(at: cacheDirectory.deletingLastPathComponent()) }

    let viewModel = PlayerViewModel(
        musicSource: SilentMusicSource(),
        lyricsProvider: NeverLyricsProvider(),
        cache: LyricsCache(directory: cacheDirectory)
    )
    let themeDefaults = try #require(UserDefaults(suiteName: "StatusItemApprovalTests.\(UUID().uuidString)"))
    let overlayDefaults = try #require(UserDefaults(suiteName: "StatusItemApprovalTests.overlay.\(UUID().uuidString)"))
    let themeManager = ThemeManager(defaults: themeDefaults)
    var guidancePresentations = 0
    let controller = StatusItemController(
        themeManager: themeManager,
        overlayController: OverlayWindowController(
            viewModel: viewModel,
            themeManager: themeManager,
            defaults: overlayDefaults
        ),
        autostartManager: AutostartManager(service: service),
        approvalPresenter: { guidancePresentations += 1 }
    )

    let statusItem = try #require(reflectedStatusItem(from: controller))
    defer { NSStatusBar.system.removeStatusItem(statusItem) }
    let selector = NSSelectorFromString("toggleAutostart")
    #expect((controller as NSObject).responds(to: selector))

    _ = (controller as NSObject).perform(selector)

    #expect(guidancePresentations == 1)
}

@Test @MainActor func menuNeedsUpdateRefreshesAutostartStatusBeforeOpen() throws {
    let service = MutableLoginItemService()
    let cacheDirectory = try makeStatusItemTestDirectory()
    defer { try? FileManager.default.removeItem(at: cacheDirectory.deletingLastPathComponent()) }

    let cache = LyricsCache(directory: cacheDirectory)
    let viewModel = PlayerViewModel(
        musicSource: SilentMusicSource(),
        lyricsProvider: NeverLyricsProvider(),
        cache: cache
    )
    let themeDefaults = try #require(UserDefaults(suiteName: "StatusItemControllerTests.\(UUID().uuidString)"))
    let overlayDefaults = try #require(UserDefaults(suiteName: "StatusItemControllerTests.overlay.\(UUID().uuidString)"))
    let themeManager = ThemeManager(defaults: themeDefaults)
    let overlayController = OverlayWindowController(
        viewModel: viewModel,
        themeManager: themeManager,
        defaults: overlayDefaults
    )
    let controller = StatusItemController(
        themeManager: themeManager,
        overlayController: overlayController,
        autostartManager: AutostartManager(service: service)
    )

    let statusItem = try #require(reflectedStatusItem(from: controller))
    defer { NSStatusBar.system.removeStatusItem(statusItem) }
    let menu = try #require(statusItem.menu)
    let selector = NSSelectorFromString("menuNeedsUpdate:")

    #expect((controller as NSObject).responds(to: selector))

    service.status = .requiresApproval
    _ = (controller as NSObject).perform(selector, with: menu)

    let approvalItem = try #require(autostartMenuItem(in: menu))
    #expect(approvalItem.title == "Launch at Login (Approval Required)")
    #expect(approvalItem.state == .off)

    service.status = .enabled
    _ = (controller as NSObject).perform(selector, with: menu)

    let enabledItem = try #require(autostartMenuItem(in: menu))
    #expect(enabledItem.title == "Launch at Login")
    #expect(enabledItem.state == .on)
}
