//
//  PomodoroTimerEngine.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Combine
import Foundation

final class PomodoroTimerEngine: ObservableObject {
    enum State: String {
        case idle
        case running
        case paused
        case breakRunning
        case breakPaused

        var isOnBreak: Bool {
            switch self {
            case .breakRunning, .breakPaused:
                return true
            case .idle, .running, .paused:
                return false
            }
        }

        var isRunning: Bool {
            self == .running || self == .breakRunning
        }

        var isPaused: Bool {
            self == .paused || self == .breakPaused
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var remainingSeconds: Int

    private let workDuration: Int
    private let breakDuration: Int
    private var timer: Timer?

    init(workDuration: Int = 25 * 60, breakDuration: Int = 5 * 60) {
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.remainingSeconds = workDuration
    }

    func start() {
        guard state == .idle else { return }
        remainingSeconds = workDuration
        state = .running
        startTimer()
    }

    func pause() {
        guard state.isRunning else { return }
        state = state.isOnBreak ? .breakPaused : .paused
        stopTimer()
    }

    func resume() {
        guard state.isPaused else { return }
        state = state.isOnBreak ? .breakRunning : .running
        startTimer()
    }

    func reset() {
        stopTimer()
        state = .idle
        remainingSeconds = workDuration
    }

    func skipBreak() {
        guard state.isOnBreak else { return }
        stopTimer()
        state = .idle
        remainingSeconds = workDuration
    }

    func startBreak() {
        guard state == .running || state == .paused else { return }
        stopTimer()
        state = .breakRunning
        remainingSeconds = breakDuration
        startTimer()
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
            handleCompletion()
            return
        }

        remainingSeconds -= 1

        if remainingSeconds == 0 {
            handleCompletion()
        }
    }

    private func handleCompletion() {
        if state.isOnBreak {
            stopTimer()
            state = .idle
            remainingSeconds = workDuration
        } else {
            state = .breakRunning
            remainingSeconds = breakDuration
        }
    }
}
