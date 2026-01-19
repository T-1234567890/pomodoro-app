//
//  MusicController.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Combine
import SwiftUI

enum MusicPlaybackState: String {
    case idle
    case playing
    case paused
}

enum MusicSource {
    case none
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
}

final class MusicController: ObservableObject {
    @Published private(set) var playbackState: MusicPlaybackState
    @Published private(set) var activeSource: MusicSource
    @Published var currentFocusSound: FocusSoundType

    private let userDefaults: UserDefaults
    private let ambientNoiseEngine: AmbientNoiseEngine

    init(
        userDefaults: UserDefaults = .standard,
        ambientNoiseEngine: AmbientNoiseEngine
    ) {
        self.userDefaults = userDefaults
        self.ambientNoiseEngine = ambientNoiseEngine
        let storedFocus = FocusSoundType(rawValue: userDefaults.string(forKey: "music.focusSound") ?? "") ?? .off
        let storedPlayback = MusicPlaybackState(rawValue: userDefaults.string(forKey: "music.playbackState") ?? "") ?? .idle
        currentFocusSound = storedFocus
        playbackState = storedPlayback
        activeSource = storedFocus == .off ? .none : .focusSound
        if storedFocus != .off, storedPlayback == .playing {
            startFocusSound(storedFocus)
        }
    }

    func play() {
        guard currentFocusSound != .off else {
            playbackState = .idle
            activeSource = .none
            persistState()
            return
        }
        startFocusSound(currentFocusSound)
    }

    func pause() {
        stopFocusSoundPlayback(keepSelection: true)
        playbackState = activeSource == .focusSound ? .paused : .idle
        persistState()
    }

    func next() {
        stopFocusSoundPlayback(keepSelection: true)
    }

    func previous() {
        stopFocusSoundPlayback(keepSelection: true)
    }

    func startFocusSound(_ type: FocusSoundType) {
        guard type != .off else {
            stopFocusSound()
            return
        }
        currentFocusSound = type
        ambientNoiseEngine.play(type: type.ambientNoiseType)
        playbackState = .playing
        activeSource = .focusSound
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
        ambientNoiseEngine.stop()
        if !keepSelection {
            currentFocusSound = .off
        }
        if activeSource == .focusSound {
            activeSource = keepSelection ? .focusSound : .none
        }
    }

    private func persistState() {
        userDefaults.set(currentFocusSound.rawValue, forKey: "music.focusSound")
        userDefaults.set(playbackState.rawValue, forKey: "music.playbackState")
    }

}

private extension FocusSoundType {
    var ambientNoiseType: AmbientNoiseEngine.NoiseType {
        switch self {
        case .off:
            return .off
        case .white:
            return .white
        case .brown:
            return .brown
        case .rain:
            return .rain
        case .wind:
            return .wind
        }
    }
}
