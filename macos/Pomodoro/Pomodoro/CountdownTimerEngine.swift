//
//  CountdownTimerEngine.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Foundation

final class CountdownTimerEngine: ObservableObject {
    enum State: String {
        case idle
        case running
        case paused

        var isRunning: Bool { self == .running }
        var isPaused: Bool { self == .paused }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var remainingSeconds: Int

    private let duration: Int
    private var timer: Timer?

    init(duration: Int = 10 * 60) {
        self.duration = duration
        self.remainingSeconds = duration
    }

    func start() {
        guard state == .idle else { return }
        remainingSeconds = duration
        state = .running
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        stopTimer()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        startTimer()
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
}
