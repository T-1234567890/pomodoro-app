//
//  NowPlayingRouter.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import Foundation

@MainActor
final class NowPlayingRouter: ObservableObject {
    @Published private(set) var title: String = ""
    @Published private(set) var artist: String = ""
    @Published private(set) var artwork: NSImage?
    @Published private(set) var sourceName: String = ""
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isAvailable: Bool = false

    private let appleMusicProvider: NowPlayingProvider
    private let spotifyProvider: NowPlayingProvider
    private let qqMusicProvider: NowPlayingProvider
    private var pollTask: Task<Void, Never>?
    private var activeProvider: NowPlayingProvider?

    init(
        appleMusicProvider: NowPlayingProvider = AppleMusicProvider(),
        spotifyProvider: NowPlayingProvider = SpotifyProvider(),
        qqMusicProvider: NowPlayingProvider = QQMusicProvider(),
        startPolling: Bool = true
    ) {
        self.appleMusicProvider = appleMusicProvider
        self.spotifyProvider = spotifyProvider
        self.qqMusicProvider = qqMusicProvider

        if startPolling {
            startPollingLoop()
        }
    }

    deinit {
        pollTask?.cancel()
    }

    func playPause() {
        guard let activeProvider else { return }
        Task {
            await activeProvider.playPause()
        }
    }

    func nextTrack() {
        guard let activeProvider else { return }
        Task {
            await activeProvider.nextTrack()
        }
    }

    func previousTrack() {
        guard let activeProvider else { return }
        Task {
            await activeProvider.previousTrack()
        }
    }

    private func startPollingLoop() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
        }
    }

    private func refresh() async {
        async let appleState = appleMusicProvider.fetchState()
        async let spotifyState = spotifyProvider.fetchState()
        _ = qqMusicProvider

        let apple = await appleState
        let spotify = await spotifyState

        if apple.isPlaying {
            apply(state: apple, provider: appleMusicProvider)
        } else if spotify.isPlaying {
            apply(state: spotify, provider: spotifyProvider)
        } else {
            clearState()
        }
    }

    private func apply(state: NowPlayingProviderState, provider: NowPlayingProvider) {
        activeProvider = provider
        title = state.title.isEmpty ? "Unknown Track" : state.title
        artist = state.artist.isEmpty ? "Unknown Artist" : state.artist
        artwork = state.artwork
        sourceName = provider.sourceName
        isPlaying = state.isPlaying
        isAvailable = true
    }

    private func clearState() {
        activeProvider = nil
        title = ""
        artist = ""
        artwork = nil
        sourceName = ""
        isPlaying = false
        isAvailable = false
    }
}
