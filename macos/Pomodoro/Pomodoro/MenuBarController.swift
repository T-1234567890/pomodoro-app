//
//  MenuBarController.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import Combine

final class MenuBarController: NSObject, NSMenuDelegate {
    private enum MenuMode {
        case pomodoro
        case breakTime
        case countdown
        case idle
    }

    private unowned let appState: AppState
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let openMainWindow: () -> Void
    private let quitHandler: () -> Void
    private var titleTimer: Timer?
    private var lastTitleUpdateSecond: Int?
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState, openMainWindow: @escaping () -> Void, quitApp: @escaping () -> Void) {
        self.appState = appState
        self.openMainWindow = openMainWindow
        self.quitHandler = quitApp
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        menu.autoenablesItems = false
        super.init()
        configureStatusItem()
        observeStateChanges()
        startTitleTimer()
    }

    deinit {
        shutdown()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.attributedTitle = statusTitleAttributedString()
        }
        updateStatusItemLength()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    private func observeStateChanges() {
        appState.pomodoro.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
                self?.updateTitleIfNeeded()
            }
            .store(in: &cancellables)

        appState.countdown.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
                self?.updateTitleIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func startTitleTimer() {
        titleTimer?.invalidate()
        let nextSecond = ceil(Date().timeIntervalSince1970)
        let fireDate = Date(timeIntervalSince1970: nextSecond)
        let timer = Timer(fire: fireDate, interval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTitleIfNeeded()
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        titleTimer = timer
    }

    private func updateTitleIfNeeded() {
        let currentSecond = Int(Date().timeIntervalSince1970)
        if lastTitleUpdateSecond == currentSecond {
            return
        }
        lastTitleUpdateSecond = currentSecond
        guard let button = statusItem.button else { return }
        button.attributedTitle = statusTitleAttributedString()
        button.toolTip = statusTooltip()
    }

    private func statusTitleAttributedString() -> NSAttributedString {
        let title = statusTitle()
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return NSAttributedString(string: title, attributes: [.font: font])
    }

    private func updateStatusItemLength() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let sampleTitles = [
            "🍅 00:00",
            "☕ 00:00",
            "🌙 00:00",
            "⏱ 00:00",
            "🍅 Ready"
        ]
        let maxWidth = sampleTitles
            .map { title in
                NSAttributedString(string: title, attributes: [.font: font]).size().width
            }
            .max() ?? 0
        if maxWidth > 0 {
            statusItem.length = ceil(maxWidth) + 6
        }
    }

    private func statusTitle() -> String {
        switch currentMenuMode() {
        case .pomodoro:
            return "🍅 \(formattedTime(appState.pomodoro.remainingSeconds))"
        case .breakTime:
            return "\(breakEmoji()) \(formattedTime(appState.pomodoro.remainingSeconds))"
        case .countdown:
            return "⏱ \(formattedTime(appState.countdown.remainingSeconds))"
        case .idle:
            return "🍅 Ready"
        }
    }

    private func statusTooltip() -> String {
        switch currentMenuMode() {
        case .pomodoro:
            return "Pomodoro running"
        case .breakTime:
            return breakTooltip()
        case .countdown:
            return "Countdown running"
        case .idle:
            return "Idle"
        }
    }

    private func currentMenuMode() -> MenuMode {
        let pomodoroState = appState.pomodoro.state
        let countdownState = appState.countdown.state

        switch pomodoroState {
        case .running, .paused:
            return .pomodoro
        case .breakRunning, .breakPaused:
            return .breakTime
        case .idle:
            break
        }

        switch countdownState {
        case .running, .paused:
            return .countdown
        case .idle, .breakRunning, .breakPaused:
            return .idle
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        switch currentMenuMode() {
        case .pomodoro:
            menu.addItem(sectionHeader(title: "Pomodoro — Work"))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: pomodoroPauseTitle(), action: #selector(pausePomodoro)))
            menu.addItem(actionItem(title: "↺ Reset", action: #selector(resetPomodoro)))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Start Break", action: #selector(startBreak)))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Open App", action: #selector(openApp)))
            menu.addItem(actionItem(title: "Quit", action: #selector(quitApp)))
        case .breakTime:
            menu.addItem(sectionHeader(title: breakMenuTitle()))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: pomodoroPauseTitle(), action: #selector(pausePomodoro)))
            menu.addItem(actionItem(title: "↺ Reset", action: #selector(resetPomodoro)))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Skip Break", action: #selector(skipBreak)))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Open App", action: #selector(openApp)))
            menu.addItem(actionItem(title: "Quit", action: #selector(quitApp)))
        case .countdown:
            menu.addItem(sectionHeader(title: "Countdown Timer"))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: countdownPauseTitle(), action: #selector(pauseCountdown)))
            menu.addItem(actionItem(title: "↺ Reset", action: #selector(resetCountdown)))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Open App", action: #selector(openApp)))
            menu.addItem(actionItem(title: "Quit", action: #selector(quitApp)))
        case .idle:
            menu.addItem(sectionHeader(title: "Pomodoro Timer"))
            menu.addItem(actionItem(title: "Start Pomodoro", action: #selector(startPomodoro)))
            menu.addItem(actionItem(title: "Start Countdown", action: #selector(startCountdown)))
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Open App", action: #selector(openApp)))
            menu.addItem(actionItem(title: "Quit", action: #selector(quitApp)))
        }

        statusItem.menu = menu
    }

    private func sectionHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func formattedTime(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let minutes = clampedSeconds / 60
        let remaining = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, remaining)
    }

    private func pomodoroPauseTitle() -> String {
        switch appState.pomodoro.state {
        case .paused, .breakPaused:
            return "▶ Resume"
        case .running, .breakRunning, .idle:
            return "⏸ Pause"
        }
    }

    private func breakMenuTitle() -> String {
        appState.pomodoroMode == .longBreak ? "Long Break" : "Break Time"
    }

    private func breakTooltip() -> String {
        appState.pomodoroMode == .longBreak ? "Long break running" : "Break running"
    }

    private func breakEmoji() -> String {
        appState.pomodoroMode == .longBreak ? "🌙" : "☕"
    }

    private func countdownPauseTitle() -> String {
        switch appState.countdown.state {
        case .paused:
            return "▶ Resume"
        case .running, .idle, .breakRunning, .breakPaused:
            return "⏸ Pause"
        }
    }

    @objc private func startPomodoro() {
        appState.startPomodoro()
    }

    @objc private func pausePomodoro() {
        appState.togglePomodoroPause()
    }

    @objc private func resetPomodoro() {
        appState.resetPomodoro()
    }

    @objc private func startBreak() {
        appState.startBreak()
    }

    @objc private func skipBreak() {
        appState.skipBreak()
    }

    @objc private func startCountdown() {
        appState.startCountdown()
    }

    @objc private func pauseCountdown() {
        appState.toggleCountdownPause()
    }

    @objc private func resetCountdown() {
        appState.resetCountdown()
    }

    @objc private func openApp() {
        openMainWindow()
    }

    @objc private func quitApp() {
        quitHandler()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateTitleIfNeeded()
        rebuildMenu()
    }

    func shutdown() {
        titleTimer?.invalidate()
        titleTimer = nil
        cancellables.removeAll()
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
