//
//  LocalMusicPlayer.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class LocalMusicPlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTrackName: String?

    private var audioPlayer: AVAudioPlayer?
    private var fileURLs: [URL] = []
    private var currentIndex = 0
    private var volume: Float = 1.0

    var hasFiles: Bool {
        !fileURLs.isEmpty
    }

    func loadFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff]

        if panel.runModal() == .OK {
            fileURLs = panel.urls
            currentIndex = 0
            preparePlayer(at: currentIndex, shouldPlay: false)
        }
    }

    func play() {
        guard hasFiles else { return }
        if audioPlayer == nil {
            preparePlayer(at: currentIndex, shouldPlay: true)
            return
        }
        audioPlayer?.play()
        isPlaying = audioPlayer?.isPlaying ?? false
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func next() {
        guard hasFiles else { return }
        let shouldPlay = isPlaying
        currentIndex = (currentIndex + 1) % fileURLs.count
        preparePlayer(at: currentIndex, shouldPlay: shouldPlay)
    }

    func previous() {
        guard hasFiles else { return }
        let shouldPlay = isPlaying
        currentIndex = (currentIndex - 1 + fileURLs.count) % fileURLs.count
        preparePlayer(at: currentIndex, shouldPlay: shouldPlay)
    }

    func setVolume(_ value: Float) {
        volume = value
        audioPlayer?.volume = value
    }

    private func preparePlayer(at index: Int, shouldPlay: Bool) {
        guard fileURLs.indices.contains(index) else { return }
        let url = fileURLs[index]
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = volume
            player.prepareToPlay()
            audioPlayer = player
            currentTrackName = url.deletingPathExtension().lastPathComponent
            if shouldPlay {
                player.play()
                isPlaying = true
            } else {
                isPlaying = false
            }
        } catch {
            audioPlayer = nil
            currentTrackName = nil
            isPlaying = false
        }
    }
}

extension LocalMusicPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard hasFiles else { return }
        currentIndex = (currentIndex + 1) % fileURLs.count
        preparePlayer(at: currentIndex, shouldPlay: true)
    }
}
