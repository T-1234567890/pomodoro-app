import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class LocalMediaPlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTrackTitle: String = "No Track Selected"
    @Published private(set) var currentArtwork: NSImage?

    private let player = AVQueuePlayer()
    private var currentItems: [AVPlayerItem] = []
    private var currentIndex: Int = 0
    private var statusObserver: NSKeyValueObservation?
    private var timeObserverToken: Any?

    override init() {
        super.init()
        observePlayerStatus()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    func loadFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["mp3", "m4a", "wav", "aiff"]
        panel.title = "Choose Audio Files"
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                self?.setQueue(with: panel.urls)
            }
        }
    }

    func play() {
        guard !currentItems.isEmpty else { return }
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func next() {
        guard !currentItems.isEmpty else { return }
        if currentIndex + 1 < currentItems.count {
            currentIndex += 1
            player.advanceToNextItem()
            updateNowPlaying(from: currentItems[currentIndex])
            if isPlaying {
                player.play()
            }
        }
    }

    func previous() {
        guard !currentItems.isEmpty else { return }
        if currentIndex > 0 {
            currentIndex -= 1
            rebuildQueue(startingAt: currentIndex)
            if isPlaying {
                player.play()
            }
        } else {
            player.seek(to: .zero)
        }
    }

    private func setQueue(with urls: [URL]) {
        let items = urls.map { AVPlayerItem(url: $0) }
        guard !items.isEmpty else { return }
        currentItems = items
        currentIndex = 0
        rebuildQueue(startingAt: 0)
        updateNowPlaying(from: items[0])
    }

    private func rebuildQueue(startingAt index: Int) {
        player.removeAllItems()
        for item in currentItems[index...] {
            player.insert(item, after: nil)
        }
        updateNowPlaying(from: currentItems[index])
    }

    private func updateNowPlaying(from item: AVPlayerItem) {
        let asset = item.asset
        let url = (asset as? AVURLAsset)?.url
        currentTrackTitle = asset.metadata
            .first(where: { $0.commonKey == .commonKeyTitle })
            .flatMap { $0.stringValue }
            ?? url?.deletingPathExtension().lastPathComponent
            ?? "Unknown Track"
        currentArtwork = asset.metadata
            .first(where: { $0.commonKey == .commonKeyArtwork })
            .flatMap { $0.dataValue }
            .flatMap { NSImage(data: $0) }
    }

    private func observePlayerStatus() {
        statusObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            guard let self, self.currentIndex < self.currentItems.count else { return }
            if self.player.currentItem !== self.currentItems[self.currentIndex],
               let newItem = self.player.currentItem,
               let newIndex = self.currentItems.firstIndex(where: { $0 === newItem }) {
                self.currentIndex = newIndex
                self.updateNowPlaying(from: newItem)
            }
        }
    }

}
