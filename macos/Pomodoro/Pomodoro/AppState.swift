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

    @Published var durationConfig: DurationConfig {
        didSet {
            updatePomodoroConfiguration()
            durationConfig.save(to: userDefaults)
        }
    }

    @Published private(set) var pomodoroMode: PomodoroTimerEngine.Mode
    @Published private(set) var pomodoroCurrentMode: PomodoroTimerEngine.CurrentMode

    private var cancellables: Set<AnyCancellable> = []
    private let userDefaults: UserDefaults

    init(
        pomodoro: PomodoroTimerEngine,
        countdown: CountdownTimerEngine,
        durationConfig: DurationConfig,
        userDefaults: UserDefaults = .standard
    ) {
        self.pomodoro = pomodoro
        self.countdown = countdown
        self.durationConfig = durationConfig
        self.pomodoroMode = pomodoro.mode
        self.pomodoroCurrentMode = pomodoro.currentMode
        self.userDefaults = userDefaults

        pomodoro.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        pomodoro.$mode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.pomodoroMode = mode
            }
            .store(in: &cancellables)

        pomodoro.$currentMode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.pomodoroCurrentMode = mode
            }
            .store(in: &cancellables)

        countdown.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        updatePomodoroConfiguration()
    }

    convenience init(
        pomodoro: PomodoroTimerEngine,
        countdown: CountdownTimerEngine,
        userDefaults: UserDefaults
    ) {
        let storedConfig = DurationConfig.load(from: userDefaults)
        self.init(
            pomodoro: pomodoro,
            countdown: countdown,
            durationConfig: storedConfig,
            userDefaults: userDefaults
        )
    }

    convenience init(
        pomodoro: PomodoroTimerEngine,
        countdown: CountdownTimerEngine
    ) {
        self.init(
            pomodoro: pomodoro,
            countdown: countdown,
            userDefaults: .standard
        )
    }

    convenience init() {
        self.init(
            pomodoro: PomodoroTimerEngine(),
            countdown: CountdownTimerEngine()
        )
    }

    private func updatePomodoroConfiguration() {
        pomodoro.updateConfiguration(
            durationConfig: durationConfig
        )
        countdown.updateConfiguration(durationConfig: durationConfig)
    }

    func startPomodoro() {
        pomodoro.start()
    }

    func togglePomodoroPause() {
        switch pomodoro.state {
        case .running, .breakRunning:
            pomodoro.pause()
        case .paused, .breakPaused:
            pomodoro.resume()
        case .idle:
            break
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
        switch countdown.state {
        case .running:
            countdown.pause()
        case .paused:
            countdown.resume()
        case .idle, .breakRunning, .breakPaused:
            break
        }
    }

    func resetCountdown() {
        countdown.reset()
    }

}
