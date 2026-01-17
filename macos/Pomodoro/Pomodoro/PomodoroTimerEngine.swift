//
//  PomodoroTimerEngine.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Combine
import Foundation

final class PomodoroTimerEngine: ObservableObject {
    enum Mode: String {
        case work
        case breakTime
        case longBreak
    }

    enum CurrentMode: String {
        case idle
        case work
        case `break`
        case longBreak
    }

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
    @Published private(set) var mode: Mode = .work
    @Published private(set) var currentMode: CurrentMode = .idle
    @Published private(set) var completedWorkSessions: Int = 0

    private var workDuration: Int
    private var breakDuration: Int
    private var longBreakDuration: Int
    private var sessionsUntilLongBreak: Int
    private var timer: Timer?

    init(
        workDuration: Int = 25 * 60,
        breakDuration: Int = 5 * 60,
        longBreakDuration: Int = 15 * 60,
        sessionsUntilLongBreak: Int = 4
    ) {
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.sessionsUntilLongBreak = max(1, sessionsUntilLongBreak)
        self.remainingSeconds = workDuration
        updateCurrentMode()
    }

    func updateConfiguration(
        workDuration: Int,
        breakDuration: Int,
        longBreakDuration: Int,
        sessionsUntilLongBreak: Int
    ) {
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.sessionsUntilLongBreak = max(1, sessionsUntilLongBreak)

        if state == .idle {
            remainingSeconds = workDuration
            mode = .work
            updateCurrentMode()
        }
    }

    func start() {
        guard state == .idle else { return }
        remainingSeconds = workDuration
        state = .running
        mode = .work
        updateCurrentMode()
        startTimer()
    }

    func pause() {
        guard state.isRunning else { return }
        state = state.isOnBreak ? .breakPaused : .paused
        updateCurrentMode()
        stopTimer()
    }

    func resume() {
        guard state.isPaused else { return }
        state = state.isOnBreak ? .breakRunning : .running
        updateCurrentMode()
        startTimer()
    }

    func reset() {
        stopTimer()
        state = .idle
        remainingSeconds = workDuration
        mode = .work
        completedWorkSessions = 0
        updateCurrentMode()
    }

    func skipBreak() {
        guard state.isOnBreak else { return }
        stopTimer()
        state = .idle
        remainingSeconds = workDuration
        if mode == .longBreak {
            completedWorkSessions = 0
        }
        mode = .work
        updateCurrentMode()
    }

    func startBreak() {
        guard state == .running || state == .paused else { return }
        stopTimer()
        beginBreak(isLongBreak: isLongBreakDue())
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
            if mode == .longBreak {
                completedWorkSessions = 0
            }
            mode = .work
            updateCurrentMode()
        } else {
            completedWorkSessions += 1
            beginBreak(isLongBreak: isLongBreakDue())
        }
    }

    private func beginBreak(isLongBreak: Bool) {
        state = .breakRunning
        mode = isLongBreak ? .longBreak : .breakTime
        remainingSeconds = isLongBreak ? longBreakDuration : breakDuration
        if isLongBreak {
            completedWorkSessions = 0
        }
        updateCurrentMode()
    }

    private func isLongBreakDue() -> Bool {
        completedWorkSessions >= sessionsUntilLongBreak
    }

    private func updateCurrentMode() {
        if state == .idle {
            currentMode = .idle
        } else if state.isOnBreak {
            currentMode = mode == .longBreak ? .longBreak : .break
        } else {
            currentMode = .work
        }
    }
}
