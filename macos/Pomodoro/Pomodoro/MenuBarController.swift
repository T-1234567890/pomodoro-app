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
    private var titleTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        menu.autoenablesItems = false
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
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    private func observeStateChanges() {
        appState.pomodoro.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
                self?.updateTitle()
            }
            .store(in: &cancellables)

        appState.countdown.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
                self?.updateTitle()
            }
            .store(in: &cancellables)
    }

    private func startTitleTimer() {
        titleTimer?.invalidate()
        titleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTitle()
        }
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        button.attributedTitle = statusTitleAttributedString()
        button.toolTip = statusTooltip()
    }

    private func statusTitleAttributedString() -> NSAttributedString {
        let title = statusTitle()
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return NSAttributedString(string: title, attributes: [.font: font])
    }

    private func statusTitle() -> String {
        switch currentMenuMode() {
        case .pomodoro:
            return "🍅 \(formattedTime(appState.pomodoro.remainingSeconds))"
        case .breakTime:
            return "☕ \(formattedTime(appState.pomodoro.remainingSeconds))"
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
            return "Break running"
        case .countdown:
            return "Countdown running"
        case .idle:
            return "Idle"
        }
    }

    private func currentMenuMode() -> MenuMode {
        if appState.pomodoro.state == .running || appState.pomodoro.state == .paused {
            return .pomodoro
        }
        if appState.pomodoro.state == .breakRunning || appState.pomodoro.state == .breakPaused {
            return .breakTime
        }
        if appState.countdown.state != .idle {
            return .countdown
        }
        return .idle
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
            menu.addItem(sectionHeader(title: "Break Time"))
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
        appState.pomodoro.state.isPaused ? "▶ Resume" : "⏸ Pause"
    }

    private func countdownPauseTitle() -> String {
        appState.countdown.state.isPaused ? "▶ Resume" : "⏸ Pause"
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
        appState.openMainWindow()
    }

    @objc private func quitApp() {
        appState.quitApp()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateTitle()
        rebuildMenu()
    }

    func shutdown() {
        titleTimer?.invalidate()
        titleTimer = nil
        cancellables.removeAll()
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
