//
//  AmbientNoiseEngine.swift
//  Pomodoro
//
//  Created by OpenAI on 2025-02-11.
//

import AVFoundation
import Foundation
import os

final class AmbientNoiseEngine {
    enum NoiseType {
        case off
        case white
        case brown
        case rain
        case wind
    }

    private struct State {
        var type: NoiseType
        var volume: Float
        var randomSeedL: UInt32
        var randomSeedR: UInt32
        var brownL: Float
        var brownR: Float
        var rainLpfL: Float
        var rainLpfR: Float
        var windLowL: Float
        var windLowR: Float
        var windHighL: Float
        var windHighR: Float
        var rainPhase: Float
    }

    private let engine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "com.pomodoro.ambient-audio", qos: .userInitiated)
    private lazy var sourceNode: AVAudioSourceNode = {
        AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frameCount = Int(frameCount)

            os_unfair_lock_lock(&self.stateLock)
            var state = self.state
            os_unfair_lock_unlock(&self.stateLock)

            let volume = state.volume
            let type = state.type

            if type == .off || volume <= 0 {
                for buffer in bufferList {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }

            let channelCount = Int(bufferList.count)
            let bufferL = bufferList[0]
            let bufferR = channelCount > 1 ? bufferList[1] : bufferList[0]
            let ptrL = bufferL.mData!.assumingMemoryBound(to: Float.self)
            let ptrR = bufferR.mData!.assumingMemoryBound(to: Float.self)

            for frame in 0..<frameCount {
                let whiteL = Self.nextWhite(seed: &state.randomSeedL)
                let whiteR = Self.nextWhite(seed: &state.randomSeedR)

                let sampleL = self.renderSample(
                    type: type,
                    white: whiteL,
                    brownState: &state.brownL,
                    rainLpf: &state.rainLpfL,
                    windLow: &state.windLowL,
                    windHigh: &state.windHighL,
                    rainPhase: &state.rainPhase
                )

                let sampleR = self.renderSample(
                    type: type,
                    white: whiteR,
                    brownState: &state.brownR,
                    rainLpf: &state.rainLpfR,
                    windLow: &state.windLowR,
                    windHigh: &state.windHighR,
                    rainPhase: &state.rainPhase
                )

                ptrL[frame] = Self.clamp(sampleL * volume)
                ptrR[frame] = Self.clamp(sampleR * volume)
            }

            os_unfair_lock_lock(&self.stateLock)
            self.state.randomSeedL = state.randomSeedL
            self.state.randomSeedR = state.randomSeedR
            self.state.brownL = state.brownL
            self.state.brownR = state.brownR
            self.state.rainLpfL = state.rainLpfL
            self.state.rainLpfR = state.rainLpfR
            self.state.windLowL = state.windLowL
            self.state.windLowR = state.windLowR
            self.state.windHighL = state.windHighL
            self.state.windHighR = state.windHighR
            self.state.rainPhase = state.rainPhase
            os_unfair_lock_unlock(&self.stateLock)

            return noErr
        }
    }()
    private let format: AVAudioFormat
    private let sampleRate: Double = 44_100
    private let rainAlpha: Float
    private let windLowAlpha: Float
    private let windHighAlpha: Float
    private let rainPhaseIncrement: Float
    private var isEnginePrepared = false
    private var stateLock = os_unfair_lock_s()
    private var state: State

    init() {
        guard let standardAudioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            preconditionFailure("Failed to create standard audio format with sample rate \(sampleRate) and 2 channels")
        }
        format = standardAudioFormat
        rainAlpha = AmbientNoiseEngine.alpha(for: 1200, sampleRate: sampleRate)
        windLowAlpha = AmbientNoiseEngine.alpha(for: 2000, sampleRate: sampleRate)
        windHighAlpha = AmbientNoiseEngine.alpha(for: 200, sampleRate: sampleRate)
        rainPhaseIncrement = Float(2.0 * Double.pi * 0.5 / sampleRate)
        state = State(
            type: .off,
            volume: 0.25,
            randomSeedL: 0x12345678,
            randomSeedR: 0x87654321,
            brownL: 0,
            brownR: 0,
            rainLpfL: 0,
            rainLpfR: 0,
            windLowL: 0,
            windLowR: 0,
            windHighL: 0,
            windHighR: 0,
            rainPhase: 0
        )

        audioQueue.async { [weak self] in
            self?.prepareEngineIfNeeded()
        }
    }

    func play(type: NoiseType) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.updateNoiseType(type)
            self.startEngineIfNeeded(for: type)
        }
    }

    func stop() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.updateNoiseType(.off)
            self.engine.stop()
        }
    }

    func setVolume(_ volume: Float) {
        let clamped = max(0, min(volume, 1))
        audioQueue.async { [weak self] in
            self?.updateVolume(clamped)
        }
    }

    private func prepareEngineIfNeeded() {
        guard !isEnginePrepared else { return }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isEnginePrepared = true
    }

    private func startEngineIfNeeded(for type: NoiseType) {
        guard type != .off else {
            engine.stop()
            return
        }

        prepareEngineIfNeeded()

        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            return
        }
    }

    private func updateNoiseType(_ type: NoiseType) {
        os_unfair_lock_lock(&stateLock)
        state.type = type
        os_unfair_lock_unlock(&stateLock)
    }

    private func updateVolume(_ volume: Float) {
        os_unfair_lock_lock(&stateLock)
        state.volume = volume
        os_unfair_lock_unlock(&stateLock)
    }

    private func renderSample(
        type: NoiseType,
        white: Float,
        brownState: inout Float,
        rainLpf: inout Float,
        windLow: inout Float,
        windHigh: inout Float,
        rainPhase: inout Float
    ) -> Float {
        switch type {
        case .off:
            return 0
        case .white:
            return white
        case .brown:
            brownState = (brownState + white * 0.02) / 1.02
            return brownState * 3.5
        case .rain:
            rainLpf += (white - rainLpf) * rainAlpha
            rainPhase += rainPhaseIncrement
            if rainPhase > Float.pi * 2 {
                rainPhase -= Float.pi * 2
            }
            let mod = 0.65 + 0.35 * sin(rainPhase)
            return rainLpf * 0.7 * mod
        case .wind:
            brownState = (brownState + white * 0.02) / 1.02
            windLow += (brownState - windLow) * windLowAlpha
            windHigh += (brownState - windHigh) * windHighAlpha
            let band = (windLow - windHigh) * 1.4
            return band
        }
    }

    private static func nextWhite(seed: inout UInt32) -> Float {
        seed = 1664525 &* seed &+ 1013904223
        let normalized = Float(seed) / Float(UInt32.max)
        return normalized * 2 - 1
    }

    private static func clamp(_ value: Float) -> Float {
        max(-1, min(1, value))
    }

    private static func alpha(for cutoff: Double, sampleRate: Double) -> Float {
        let x = -2.0 * Double.pi * cutoff / sampleRate
        return Float(1.0 - exp(x))
    }
}
