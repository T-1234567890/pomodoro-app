import AppKit
import MediaPlayer
import AVFoundation

@MainActor
final class SystemMediaController: ObservableObject {
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var title: String = "No Track Selected"
    @Published private(set) var artist: String?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var lastUpdatedAt: Date?

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let defaults: UserDefaults

    private enum CacheKey {
        static let title = "SystemMediaController.title"
        static let artist = "SystemMediaController.artist"
        static let artwork = "SystemMediaController.artwork"
        static let lastUpdatedAt = "SystemMediaController.lastUpdatedAt"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        restoreCachedMetadata()
    }

    func play() {
        activateAudioSessionIfNeeded()
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

    private func activateAudioSessionIfNeeded() {
        guard !isSessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
            isSessionActive = true
        } catch {
            isSessionActive = false
        }
    }

    private func refreshNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        let info = infoCenter.nowPlayingInfo ?? [:]

        let playbackState = resolvePlaybackState(infoCenter: infoCenter, info: info)
        if playbackState != .unknown {
            isPlaying = playbackState == .playing
        }

        guard !info.isEmpty else { return }

        let newTitle = info[MPMediaItemPropertyTitle] as? String ?? "Unknown Title"
        let newArtist = info[MPMediaItemPropertyArtist] as? String
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
}
