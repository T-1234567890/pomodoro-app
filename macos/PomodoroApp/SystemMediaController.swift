import AppKit
import MediaPlayer

@MainActor
final class SystemMediaController: ObservableObject {
    @Published private(set) var trackTitle: String = "No System Audio"
    @Published private(set) var artistName: String?
    @Published private(set) var playbackState: MPNowPlayingPlaybackState = .stopped
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentArtwork: NSImage?

    private let commandCenter = MPRemoteCommandCenter.shared()
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?

    init(notificationCenter: NotificationCenter = .default) {
        observers.append(notificationCenter.addObserver(
            forName: .MPNowPlayingInfoCenterNowPlayingInfoDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNowPlayingInfo()
        })

        observers.append(notificationCenter.addObserver(
            forName: .MPNowPlayingInfoCenterPlaybackStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPlaybackState()
        })

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshNowPlayingInfo()
        }

        refreshNowPlayingInfo()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        refreshTimer?.invalidate()
    }

    func play() {
        sendCommand(commandCenter.playCommand)
    }

    func pause() {
        sendCommand(commandCenter.pauseCommand)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func nextTrack() {
        sendCommand(commandCenter.nextTrackCommand)
    }

    func previousTrack() {
        sendCommand(commandCenter.previousTrackCommand)
    }

    private func refreshNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        let info = infoCenter.nowPlayingInfo ?? [:]

        let title = info[MPMediaItemPropertyTitle] as? String
        let artist = info[MPMediaItemPropertyArtist] as? String
        let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork
        let artworkImage = artwork?.image(at: NSSize(width: 64, height: 64))

        trackTitle = title ?? (info.isEmpty ? "No System Audio" : "Unknown Title")
        artistName = artist
        currentArtwork = artworkImage

        refreshPlaybackState()
    }

    private func refreshPlaybackState() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        let info = infoCenter.nowPlayingInfo ?? [:]
        let rate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0

        if infoCenter.playbackState != .unknown {
            playbackState = infoCenter.playbackState
        } else if rate > 0 {
            playbackState = .playing
        } else if info.isEmpty {
            playbackState = .stopped
        } else {
            playbackState = .paused
        }

        isPlaying = playbackState == .playing
    }

    private func sendCommand(_ command: MPRemoteCommand) {
        guard command.isEnabled else { return }
        command.sendAction()
    }
}
