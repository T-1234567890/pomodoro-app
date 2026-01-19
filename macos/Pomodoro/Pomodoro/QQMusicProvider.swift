//
//  QQMusicProvider.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit

/// Placeholder provider for a future official QQ Music SDK integration.
/// This remains disabled until an official SDK is available.
final class QQMusicProvider: NowPlayingProvider {
    let sourceName = "QQ Music"

    func fetchState() async -> NowPlayingProviderState {
        NowPlayingProviderState(isRunning: false, isPlaying: false, title: "", artist: "", artwork: nil)
    }

    func playPause() async {}
    func nextTrack() async {}
    func previousTrack() async {}
}
