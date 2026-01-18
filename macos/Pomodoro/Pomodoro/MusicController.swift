//
//  MusicController.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AVFoundation
import MediaPlayer

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
        if let resourceName = type.resourceName,
           let url = Bundle.main.url(forResource: resourceName, withExtension: "wav") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            } catch {
                return nil
            }
        }

        guard let data = makeSynthesizedWavData(for: type) else {
            return nil
        }

        do {
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    private func makeSynthesizedWavData(for type: FocusSoundType) -> Data? {
        guard type != .off else { return nil }

        let sampleRate = 44_100
        let durationSeconds = 5
        let frameCount = sampleRate * durationSeconds
        let channelCount = 1
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let blockAlign = channelCount * bytesPerSample
        let byteRate = sampleRate * blockAlign
        let dataByteCount = frameCount * blockAlign

        var samples = [Int16]()
        samples.reserveCapacity(frameCount)

        var brownAccumulator: Double = 0
        var rainDropEnvelope: Double = 0
        var windModulationPhase: Double = 0

        for _ in 0..<frameCount {
            let white = Double.random(in: -1...1)
            var sample: Double

            switch type {
            case .white:
                sample = white
            case .brown:
                brownAccumulator = (brownAccumulator + white * 0.02).clamped(to: -1...1)
                sample = brownAccumulator * 1.2
            case .rain:
                rainDropEnvelope = max(rainDropEnvelope - 0.003, 0)
                if Double.random(in: 0...1) > 0.995 {
                    rainDropEnvelope = Double.random(in: 0.4...1.0)
                }
                let hiss = white * 0.3
                let drops = rainDropEnvelope * Double.random(in: -1...1) * 0.7
                sample = hiss + drops
            case .wind:
                windModulationPhase += 0.0008
                let modulator = (sin(windModulationPhase * .pi * 2) + 1) * 0.5
                sample = white * (0.2 + 0.8 * modulator)
            case .off:
                sample = 0
            }

            let clipped = max(-1.0, min(1.0, sample))
            samples.append(Int16(clipped * Double(Int16.max)))
        }

        var data = Data()
        data.reserveCapacity(44 + dataByteCount)
        data.append(contentsOf: "RIFF".utf8)
        data.append(UInt32(36 + dataByteCount).littleEndianBytes)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(UInt32(16).littleEndianBytes)
        data.append(UInt16(1).littleEndianBytes)
        data.append(UInt16(channelCount).littleEndianBytes)
        data.append(UInt32(sampleRate).littleEndianBytes)
        data.append(UInt32(byteRate).littleEndianBytes)
        data.append(UInt16(blockAlign).littleEndianBytes)
        data.append(UInt16(bitsPerSample).littleEndianBytes)
        data.append(contentsOf: "data".utf8)
        data.append(UInt32(dataByteCount).littleEndianBytes)

        for sample in samples {
            data.append(sample.littleEndianBytes)
        }

        return data
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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian, Array.init)
    }
}
