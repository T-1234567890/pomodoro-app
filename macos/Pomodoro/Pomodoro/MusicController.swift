//
//  MusicController.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

enum MusicPlaybackState: String {
    case idle
    case playing
    case paused
}

enum MusicSource {
    case none
    case system
    case focusSound
}

enum FocusSoundType: String, CaseIterable, Identifiable {
    case off
    case white
    case brown
    case rain
    case wind

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .white:
            return "White"
        case .brown:
            return "Brown"
        case .rain:
            return "Rain"
        case .wind:
            return "Wind"
        }
    }

    var resourceName: String? {
        switch self {
        case .off:
            return nil
        case .white:
            return "white"
        case .brown:
            return "brown"
        case .rain:
            return "rain"
        case .wind:
            return "wind"
        }
    }
}

final class MusicController: ObservableObject {
    @Published private(set) var playbackState: MusicPlaybackState
    @Published private(set) var activeSource: MusicSource
    @Published var currentFocusSound: FocusSoundType

    private let systemMediaController: SystemMediaController
    private let userDefaults: UserDefaults
    private var focusPlayer: AVAudioPlayer?

    init(
        systemMediaController: SystemMediaController = SystemMediaController(),
        userDefaults: UserDefaults = .standard
    ) {
        self.systemMediaController = systemMediaController
        self.userDefaults = userDefaults
        let storedFocus = FocusSoundType(rawValue: userDefaults.string(forKey: "music.focusSound") ?? "") ?? .off
        let storedPlayback = MusicPlaybackState(rawValue: userDefaults.string(forKey: "music.playbackState") ?? "") ?? .idle
        currentFocusSound = storedFocus
        playbackState = storedPlayback
        activeSource = storedFocus == .off ? .none : .focusSound
        if storedFocus == .off {
            let systemState = Self.mapSystemPlaybackState(MPNowPlayingInfoCenter.default().playbackState)
            playbackState = systemState
            activeSource = systemState == .idle ? .none : .system
        } else if storedPlayback == .playing {
            startFocusSound(storedFocus)
        }
    }

    func play() {
        if activeSource == .focusSound, currentFocusSound != .off {
            startFocusSound(currentFocusSound)
            return
        }
        stopFocusSoundPlayback(keepSelection: true)
        systemMediaController.playPause()
        activeSource = .system
        playbackState = .playing
        persistState()
    }

    func pause() {
        switch activeSource {
        case .focusSound:
            stopFocusSoundPlayback(keepSelection: true)
            playbackState = .paused
            persistState()
        case .system:
            pauseSystemIfNeeded()
            playbackState = .paused
            persistState()
        case .none:
            playbackState = .paused
            persistState()
        }
    }

    func next() {
        stopFocusSoundPlayback(keepSelection: true)
        systemMediaController.nextTrack()
        activeSource = .system
        playbackState = .playing
        persistState()
    }

    func previous() {
        stopFocusSoundPlayback(keepSelection: true)
        systemMediaController.previousTrack()
        activeSource = .system
        playbackState = .playing
        persistState()
    }

    func startFocusSound(_ type: FocusSoundType) {
        guard type != .off else {
            stopFocusSound()
            return
        }
        stopFocusSoundPlayback(keepSelection: false)
        pauseSystemIfNeeded()
        currentFocusSound = type
        if let player = makeFocusPlayer(for: type) {
            focusPlayer = player
            player.numberOfLoops = -1
            player.play()
            playbackState = .playing
            activeSource = .focusSound
        } else {
            playbackState = .idle
            activeSource = .none
        }
        persistState()
    }

    func stopFocusSound() {
        stopFocusSoundPlayback(keepSelection: false)
        currentFocusSound = .off
        activeSource = .none
        playbackState = .idle
        persistState()
    }

    private func stopFocusSoundPlayback(keepSelection: Bool) {
        focusPlayer?.stop()
        focusPlayer = nil
        if !keepSelection {
            currentFocusSound = .off
        }
        if activeSource == .focusSound {
            activeSource = keepSelection ? .focusSound : .none
        }
    }

    private func makeFocusPlayer(for type: FocusSoundType) -> AVAudioPlayer? {
        guard let resourceName = type.resourceName,
              let url = Bundle.main.url(forResource: resourceName, withExtension: "wav") else {
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    private func pauseSystemIfNeeded() {
        if MPNowPlayingInfoCenter.default().playbackState == .playing {
            systemMediaController.playPause()
        }
    }

    private func persistState() {
        userDefaults.set(currentFocusSound.rawValue, forKey: "music.focusSound")
        userDefaults.set(playbackState.rawValue, forKey: "music.playbackState")
    }

    private static func mapSystemPlaybackState(_ state: MPNowPlayingPlaybackState) -> MusicPlaybackState {
        switch state {
        case .playing:
            return .playing
        case .paused:
            return .paused
        default:
            return .idle
        }
    }
}
