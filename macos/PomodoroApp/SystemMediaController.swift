import AppKit
import MediaPlayer

@MainActor
final class SystemMediaController: ObservableObject {
    @Published private(set) var isActive: Bool = false
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var title: String = "No Track Selected"
    @Published private(set) var artist: String?
    @Published private(set) var sourceApp: String?
    @Published private(set) var currentArtwork: NSImage?

    private let commandCenter = MPRemoteCommandCenter.shared()
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    private var nowPlayingObserver: NSKeyValueObservation?
    private var playbackStateObserver: NSKeyValueObservation?
    private var commandTargets: [(command: MPRemoteCommand, token: Any)] = []
    private var lastSnapshot: NowPlayingSnapshot?

    init(notificationCenter: NotificationCenter = .default) {
        registerRemoteCommandHandlers()
        observeNowPlayingInfo(notificationCenter: notificationCenter)
        startPolling()
        refreshNowPlayingInfo()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        refreshTimer?.invalidate()
        commandTargets.forEach { entry in
            entry.command.removeTarget(entry.token)
        }
    }

    func play() {
        sendCommand(commandCenter.playCommand)
    }

    func pause() {
        sendCommand(commandCenter.pauseCommand)
    }

    func togglePlayPause() {
        sendCommand(commandCenter.togglePlayPauseCommand)
    }

    func nextTrack() {
        sendCommand(commandCenter.nextTrackCommand)
    }

    func previousTrack() {
        sendCommand(commandCenter.previousTrackCommand)
    }

    private func registerRemoteCommandHandlers() {
        commandTargets.append((commandCenter.playCommand, commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }))
        commandTargets.append((commandCenter.pauseCommand, commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }))
        commandTargets.append((commandCenter.togglePlayPauseCommand, commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }))
        commandTargets.append((commandCenter.nextTrackCommand, commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }))
        commandTargets.append((commandCenter.previousTrackCommand, commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }))
    }

    private func observeNowPlayingInfo(notificationCenter: NotificationCenter) {
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
            self?.refreshNowPlayingInfo()
        })

        let infoCenter = MPNowPlayingInfoCenter.default()
        nowPlayingObserver = infoCenter.observe(\.nowPlayingInfo, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshNowPlayingInfo()
            }
        }
        playbackStateObserver = infoCenter.observe(\.playbackState, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshNowPlayingInfo()
            }
        }
    }

    private func startPolling() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.refreshNowPlayingInfo()
        }
    }

    private func refreshNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        let info = infoCenter.nowPlayingInfo ?? [:]

        let playbackState = resolvePlaybackState(infoCenter: infoCenter, info: info)
        let isPlaying = playbackState == .playing
        let hasNowPlaying = !info.isEmpty
        let isActive = hasNowPlaying || playbackState == .playing || playbackState == .paused

        let title = info[MPMediaItemPropertyTitle] as? String
        let artist = info[MPMediaItemPropertyArtist] as? String
        let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork
        let artworkImage = artwork?.image(at: NSSize(width: 64, height: 64))
        let artworkData = artworkImage?.tiffRepresentation

        let sourceApp = info[MPNowPlayingInfoPropertyServiceIdentifier] as? String
            ?? info[MPNowPlayingInfoPropertyExternalContentIdentifier] as? String

        let resolvedTitle = title ?? (hasNowPlaying ? "Unknown Title" : "No Track Selected")

        let snapshot = NowPlayingSnapshot(
            isActive: isActive,
            isPlaying: isPlaying,
            title: resolvedTitle,
            artist: artist,
            sourceApp: sourceApp,
            artworkData: artworkData
        )

        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot

        self.isActive = snapshot.isActive
        self.isPlaying = snapshot.isPlaying
        self.title = snapshot.title
        self.artist = snapshot.artist
        self.sourceApp = snapshot.sourceApp
        if snapshot.artworkData != currentArtwork?.tiffRepresentation {
            self.currentArtwork = artworkImage
        }
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
}

private struct NowPlayingSnapshot: Equatable {
    let isActive: Bool
    let isPlaying: Bool
    let title: String
    let artist: String?
    let sourceApp: String?
    let artworkData: Data?
}
