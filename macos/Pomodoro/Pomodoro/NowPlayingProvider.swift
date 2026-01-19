//
//  NowPlayingProvider.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit

struct NowPlayingProviderState {
    let isRunning: Bool
    let isPlaying: Bool
    let title: String
    let artist: String
    let artwork: NSImage?
}

protocol NowPlayingProvider {
    var sourceName: String { get }
    func fetchState() async -> NowPlayingProviderState
    func playPause() async
    func nextTrack() async
    func previousTrack() async
}
