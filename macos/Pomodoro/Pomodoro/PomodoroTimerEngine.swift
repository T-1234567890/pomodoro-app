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

    @Published private(set) var state: TimerState = .idle
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
        switch state {
        case .running:
            state = .paused
        case .breakRunning:
            state = .breakPaused
        case .idle, .paused, .breakPaused:
            return
        }
        updateCurrentMode()
        stopTimer()
    }

    func resume() {
        switch state {
        case .paused:
            state = .running
        case .breakPaused:
            state = .breakRunning
        case .idle, .running, .breakRunning:
            return
        }
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
        switch state {
        case .breakRunning, .breakPaused:
            break
        case .idle, .running, .paused:
            return
        }
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
        switch state {
        case .running, .paused:
            break
        case .idle, .breakRunning, .breakPaused:
            return
        }
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
        switch state {
        case .breakRunning, .breakPaused:
            stopTimer()
            state = .idle
            remainingSeconds = workDuration
            if mode == .longBreak {
                completedWorkSessions = 0
            }
            mode = .work
            updateCurrentMode()
        case .running, .paused:
            completedWorkSessions += 1
            beginBreak(isLongBreak: isLongBreakDue())
        case .idle:
            break
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
        switch state {
        case .idle:
            currentMode = .idle
        case .breakRunning, .breakPaused:
            currentMode = mode == .longBreak ? .longBreak : .break
        case .running, .paused:
            currentMode = .work
        }
    }
}
