//
//  AppState.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import Combine
import SwiftUI

final class AppState: ObservableObject {
    let pomodoro: PomodoroTimerEngine
    let countdown: CountdownTimerEngine

    private var menuBarController: MenuBarController?
    private var cancellables: Set<AnyCancellable> = []

    init(
        pomodoro: PomodoroTimerEngine = PomodoroTimerEngine(),
        countdown: CountdownTimerEngine = CountdownTimerEngine()
    ) {
        self.pomodoro = pomodoro
        self.countdown = countdown

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

        menuBarController = MenuBarController(appState: self)
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

    func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
