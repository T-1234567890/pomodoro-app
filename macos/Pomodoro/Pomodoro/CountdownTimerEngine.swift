//
//  CountdownTimerEngine.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Combine
import Foundation

final class CountdownTimerEngine: ObservableObject {
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var remainingSeconds: Int

    private var durationConfig: DurationConfig
    private let durationProvider: (DurationConfig) -> Int
    private var timer: Timer?

    init(
        durationConfig: DurationConfig = .standard,
        durationProvider: @escaping (DurationConfig) -> Int = { $0.countdownDuration }
    ) {
        self.durationConfig = durationConfig
        self.durationProvider = durationProvider
        let resolvedDuration = durationProvider(durationConfig)
        self.remainingSeconds = resolvedDuration
    }

    func updateConfiguration(durationConfig: DurationConfig) {
        self.durationConfig = durationConfig

        if state == .idle {
            remainingSeconds = duration
        }
    }

    func start() {
        guard state == .idle else { return }
        remainingSeconds = duration
        state = .running
        startTimer()
    }

    func pause() {
        switch state {
        case .running:
            state = .paused
            stopTimer()
        case .idle, .paused, .breakRunning, .breakPaused:
            return
        }
    }

    func resume() {
        switch state {
        case .paused:
            state = .running
            startTimer()
        case .idle, .running, .breakRunning, .breakPaused:
            return
        }
    }

    func reset() {
        stopTimer()
        state = .idle
        remainingSeconds = duration
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            complete()
            return
        }

        remainingSeconds -= 1

        if remainingSeconds == 0 {
            complete()
        }
    }

    private func complete() {
        stopTimer()
        state = .idle
        remainingSeconds = duration
    }

    private var duration: Int {
        durationProvider(durationConfig)
    }
}
