//
//  AppState.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Combine
import SwiftUI

final class AppState: ObservableObject {
    let pomodoro: PomodoroTimerEngine
    let countdown: CountdownTimerEngine

    @Published var workDuration: Int {
        didSet { updatePomodoroConfiguration() }
    }
    @Published var breakDuration: Int {
        didSet { updatePomodoroConfiguration() }
    }
    @Published var longBreakDuration: Int {
        didSet { updatePomodoroConfiguration() }
    }
    @Published var sessionsUntilLongBreak: Int {
        didSet { updatePomodoroConfiguration() }
    }

    var pomodoroMode: PomodoroTimerEngine.Mode {
        pomodoro.mode
    }

    private var cancellables: Set<AnyCancellable> = []

    init(
        pomodoro: PomodoroTimerEngine = PomodoroTimerEngine(),
        countdown: CountdownTimerEngine = CountdownTimerEngine(),
        workDuration: Int = 25 * 60,
        breakDuration: Int = 5 * 60,
        longBreakDuration: Int = 15 * 60,
        sessionsUntilLongBreak: Int = 4
    ) {
        self.pomodoro = pomodoro
        self.countdown = countdown
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.sessionsUntilLongBreak = sessionsUntilLongBreak

        pomodoro.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        countdown.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        updatePomodoroConfiguration()
    }

    private func updatePomodoroConfiguration() {
        pomodoro.updateConfiguration(
            workDuration: workDuration,
            breakDuration: breakDuration,
            longBreakDuration: longBreakDuration,
            sessionsUntilLongBreak: sessionsUntilLongBreak
        )
    }

    func startPomodoro() {
        pomodoro.start()
    }

    func togglePomodoroPause() {
        if pomodoro.state.isRunning {
            pomodoro.pause()
        } else if pomodoro.state.isPaused {
            pomodoro.resume()
        }
    }

    func resetPomodoro() {
        pomodoro.reset()
    }

    func startBreak() {
        pomodoro.startBreak()
    }

    func skipBreak() {
        pomodoro.skipBreak()
    }

    func startCountdown() {
        countdown.start()
    }

    func toggleCountdownPause() {
        if countdown.state.isRunning {
            countdown.pause()
        } else if countdown.state.isPaused {
            countdown.resume()
        }
    }

    func resetCountdown() {
        countdown.reset()
    }

}
