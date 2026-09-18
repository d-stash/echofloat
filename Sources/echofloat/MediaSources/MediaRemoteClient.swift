import Foundation
import Darwin

enum MediaRemoteCommand: Equatable {
    case play
    case pause
    case next
    case previous
}

protocol MediaRemoteClient {
    func registerForNowPlayingNotifications(handler: @escaping (NowPlayingState?) -> Void)
    func sendCommand(_ command: MediaRemoteCommand)
}

/// Bridges Apple's private MediaRemote.framework without linking it at build time.
final class LiveMediaRemoteClient: MediaRemoteClient {
    private typealias GetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias RegisterForNotificationsFunction = @convention(c) (DispatchQueue) -> Void
    private typealias SendCommandFunction = @convention(c) (Int, AnyObject?) -> Bool

    private let handle: UnsafeMutableRawPointer
    private var updateHandler: ((NowPlayingState?) -> Void)?
    private var notificationObserver: NSObjectProtocol?

    init?() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ) else { return nil }
        self.handle = handle
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
        dlclose(handle)
    }

    func registerForNowPlayingNotifications(handler: @escaping (NowPlayingState?) -> Void) {
        updateHandler = handler
        guard let registerPtr = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
              let getInfoPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { return }

        let register = unsafeBitCast(registerPtr, to: RegisterForNotificationsFunction.self)
        register(DispatchQueue.main)

        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchNowPlayingInfo(using: getInfoPtr)
        }
        fetchNowPlayingInfo(using: getInfoPtr)
    }

    private func fetchNowPlayingInfo(using getInfoPtr: UnsafeMutableRawPointer) {
        let getInfo = unsafeBitCast(getInfoPtr, to: GetNowPlayingInfoFunction.self)
        getInfo(DispatchQueue.main) { [weak self] info in
            self?.updateHandler?(Self.mapToState(info))
        }
    }

    static func mapToState(_ info: [String: Any]) -> NowPlayingState? {
        guard let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String else { return nil }
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist"
        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
        let durationSeconds = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double).map { Int($0) }
        let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
        let isPlaying = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
        let track = TrackSignature(title: title, artist: artist, album: album, durationSeconds: durationSeconds)
        return NowPlayingState(
            track: track,
            sourceAppName: sourceName(from: info),
            status: isPlaying ? .playing : .paused,
            elapsedSeconds: elapsed,
            capturedAt: Date()
        )
    }

    private static func sourceName(from info: [String: Any]) -> String {
        let directKeys = [
            "kMRMediaRemoteNowPlayingInfoClientName",
            "kMRMediaRemoteNowPlayingInfoAppName",
            "kMRMediaRemoteNowPlayingInfoBundleIdentifier"
        ]
        for key in directKeys {
            if let value = info[key] as? String, !value.isEmpty {
                return value
            }
        }
        if let properties = info["kMRMediaRemoteNowPlayingInfoClientProperties"] as? [String: Any] {
            for key in ["name", "displayName", "bundleIdentifier"] {
                if let value = properties[key] as? String, !value.isEmpty {
                    return value
                }
            }
        }
        return "Source unavailable"
    }

    func sendCommand(_ command: MediaRemoteCommand) {
        guard let sendPtr = dlsym(handle, "MRMediaRemoteSendCommand") else { return }
        let send = unsafeBitCast(sendPtr, to: SendCommandFunction.self)
        let code: Int
        switch command {
        case .play: code = 0
        case .pause: code = 1
        case .next: code = 4
        case .previous: code = 5
        }
        _ = send(code, nil)
    }
}
