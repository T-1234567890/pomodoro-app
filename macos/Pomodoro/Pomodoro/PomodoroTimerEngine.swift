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

    private var durationConfig: DurationConfig
    private var timer: Timer?

    init(
        durationConfig: DurationConfig = .standard
    ) {
        self.durationConfig = durationConfig
        self.remainingSeconds = durationConfig.workDuration
        updateCurrentMode()
    }

    func updateConfiguration(durationConfig: DurationConfig) {
        self.durationConfig = durationConfig

        if state == .idle {
            remainingSeconds = durationConfig.workDuration
            mode = .work
            updateCurrentMode()
        }
    }

    func start() {
        guard state == .idle else { return }
        remainingSeconds = durationConfig.workDuration
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
        remainingSeconds = durationConfig.workDuration
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
        remainingSeconds = durationConfig.workDuration
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
            remainingSeconds = durationConfig.workDuration
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
        remainingSeconds = isLongBreak ? durationConfig.longBreakDuration : durationConfig.shortBreakDuration
        if isLongBreak {
            completedWorkSessions = 0
        }
        updateCurrentMode()
    }

    private func isLongBreakDue() -> Bool {
        // Choose a long break on exact interval boundaries without resetting the counter.
        return completedWorkSessions > 0
            && completedWorkSessions % durationConfig.longBreakInterval == 0
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
