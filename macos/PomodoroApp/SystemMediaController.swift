import AppKit
import MediaPlayer

@MainActor
final class SystemMediaController: ObservableObject {
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var title: String = "Nothing Playing"
    @Published private(set) var artist: String?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var lastUpdatedAt: Date?

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let defaults: UserDefaults
    private var notificationTokens: [NSObjectProtocol] = []

    private enum CacheKey {
        static let title = "SystemMediaController.title"
        static let artist = "SystemMediaController.artist"
        static let artwork = "SystemMediaController.artwork"
        static let lastUpdatedAt = "SystemMediaController.lastUpdatedAt"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        restoreCachedMetadata()
        startObserving()
    }

    func connect() {
        #if DEBUG
        print("[SystemMediaController] connect() called - refreshing now playing info")
        #endif
        refreshNowPlayingInfo()
    }

    func play() {
        sendCommand(commandCenter.playCommand)
        refreshNowPlayingInfo()
    }

    func pause() {
        sendCommand(commandCenter.pauseCommand)
        refreshNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func nextTrack() {
        sendCommand(commandCenter.nextTrackCommand)
        refreshNowPlayingInfo()
    }

    func previousTrack() {
        sendCommand(commandCenter.previousTrackCommand)
        refreshNowPlayingInfo()
    }

    private func refreshNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        let info = infoCenter.nowPlayingInfo ?? [:]

        let playbackState = resolvePlaybackState(infoCenter: infoCenter, info: info)
        if playbackState != .unknown {
            isPlaying = playbackState == .playing
        }

        let hasSession = !info.isEmpty || playbackState != .unknown
        isSessionActive = hasSession

        guard hasSession, !info.isEmpty else {
            isPlaying = false
            title = "Nothing Playing"
            artist = nil
            artwork = nil
            lastUpdatedAt = nil
            cacheMetadata(title: title, artist: nil, artwork: nil, lastUpdatedAt: Date())
            return
        }

        let newTitle = info[MPMediaItemPropertyTitle] as? String ?? "Unknown Title"
        let newArtist = (info[MPMediaItemPropertyArtist] as? String)
            ?? (info[MPMediaItemPropertyAlbumArtist] as? String)
        let newArtwork = (info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork)
            .flatMap { $0.image(at: NSSize(width: 64, height: 64)) }
        let updatedAt = Date()

        title = newTitle
        artist = newArtist
        if newArtwork?.tiffRepresentation != artwork?.tiffRepresentation {
            artwork = newArtwork
        }
        lastUpdatedAt = updatedAt

        cacheMetadata(title: newTitle, artist: newArtist, artwork: newArtwork, lastUpdatedAt: updatedAt)
    }

    private func resolvePlaybackState(
        infoCenter: MPNowPlayingInfoCenter,
        info: [String: Any]
    ) -> MPNowPlayingPlaybackState {
        if infoCenter.playbackState != .unknown {
            return infoCenter.playbackState
        }

        let rate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
        if rate > 0 {
            return .playing
        }

        return info.isEmpty ? .stopped : .paused
    }

    private func sendCommand(_ command: MPRemoteCommand) {
        guard command.isEnabled else { return }
        command.sendAction()
    }

    private func cacheMetadata(title: String, artist: String?, artwork: NSImage?, lastUpdatedAt: Date) {
        defaults.set(title, forKey: CacheKey.title)
        defaults.set(artist, forKey: CacheKey.artist)
        defaults.set(artwork?.tiffRepresentation, forKey: CacheKey.artwork)
        defaults.set(lastUpdatedAt.timeIntervalSince1970, forKey: CacheKey.lastUpdatedAt)
    }

    private func restoreCachedMetadata() {
        if let cachedTitle = defaults.string(forKey: CacheKey.title) {
            title = cachedTitle
        }
        artist = defaults.string(forKey: CacheKey.artist)
        if let artworkData = defaults.data(forKey: CacheKey.artwork) {
            artwork = NSImage(data: artworkData)
        }
        if defaults.object(forKey: CacheKey.lastUpdatedAt) != nil {
            let interval = defaults.double(forKey: CacheKey.lastUpdatedAt)
            lastUpdatedAt = Date(timeIntervalSince1970: interval)
        }
    }

    private func startObserving() {
        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: .MPNowPlayingInfoCenterNowPlayingInfoDidChange,
                object: MPNowPlayingInfoCenter.default(),
                queue: .main
            ) { [weak self] _ in
                self?.refreshNowPlayingInfo()
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: .MPNowPlayingInfoCenterPlaybackStateDidChange,
                object: MPNowPlayingInfoCenter.default(),
                queue: .main
            ) { [weak self] _ in
                self?.refreshNowPlayingInfo()
            }
        )
        // refreshNowPlayingInfo() will be called by connect() when invoked from MainWindowView.task after first render completes
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
