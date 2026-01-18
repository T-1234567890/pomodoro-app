//
//  AppState.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Combine
import SwiftUI
import UserNotifications

final class AppState: ObservableObject {
    let pomodoro: PomodoroTimerEngine
    let countdown: CountdownTimerEngine

    @Published var durationConfig: DurationConfig {
        didSet {
            updatePomodoroConfiguration()
            durationConfig.save(to: userDefaults)
        }
    }

    @Published var presetSelection: PresetSelection

    @Published private(set) var pomodoroMode: PomodoroTimerEngine.Mode
    @Published private(set) var pomodoroCurrentMode: PomodoroTimerEngine.CurrentMode
    @Published private(set) var dailyStats: DailyStats
    @Published var notificationPreference: NotificationPreference {
        didSet {
            saveNotificationPreference()
            requestNotificationAuthorizationIfNeeded()
        }
    }
    @Published var reminderPreference: ReminderPreference {
        didSet {
            saveReminderPreference()
            requestNotificationAuthorizationIfNeeded()
        }
    }

    private var cancellables: Set<AnyCancellable> = []
    private let userDefaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private var pomodoroDidReachZero = false
    private var countdownDidReachZero = false
    private var pomodoroReminderSent = false
    private var countdownReminderSent = false
    private var lastPomodoroState: TimerState?
    private var lastCountdownState: TimerState?
    private var lastBreakMode: PomodoroTimerEngine.CurrentMode?
    private var currentFocusDurationSeconds: Int?
    private var currentBreakDurationSeconds: Int?

    // Designated initializer - no default arguments to avoid linker symbol issues
    init(
        pomodoro: PomodoroTimerEngine,
        countdown: CountdownTimerEngine,
        durationConfig: DurationConfig,
        userDefaults: UserDefaults
    ) {
        self.pomodoro = pomodoro
        self.countdown = countdown
        self.durationConfig = durationConfig
        self.presetSelection = PresetSelection.selection(for: durationConfig)
        self.pomodoroMode = pomodoro.mode
        self.pomodoroCurrentMode = pomodoro.currentMode
        self.dailyStats = Self.loadDailyStats(from: userDefaults)
        self.userDefaults = userDefaults
        self.notificationCenter = UNUserNotificationCenter.current()
        self.notificationPreference = NotificationPreference(
            rawValue: userDefaults.string(forKey: DefaultsKey.notificationPreference) ?? ""
        ) ?? .off
        self.reminderPreference = ReminderPreference(
            rawValue: userDefaults.string(forKey: DefaultsKey.reminderPreference) ?? ""
        ) ?? .off
        self.lastPomodoroState = pomodoro.state
        self.lastCountdownState = countdown.state

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

        pomodoro.$remainingSeconds
            .removeDuplicates()
            .sink { [weak self] seconds in
                self?.handlePomodoroRemaining(seconds)
            }
            .store(in: &cancellables)

        pomodoro.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.handlePomodoroStateChange(state)
            }
            .store(in: &cancellables)

        countdown.$remainingSeconds
            .removeDuplicates()
            .sink { [weak self] seconds in
                self?.handleCountdownRemaining(seconds)
            }
            .store(in: &cancellables)

        countdown.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.handleCountdownStateChange(state)
            }
            .store(in: &cancellables)

        updatePomodoroConfiguration()
        refreshDailyStatsForCurrentDay()
    }

    // Convenience initializer with explicit UserDefaults forwarding
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

    // Convenience initializer with explicit standard UserDefaults
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

    // Parameterless convenience initializer with explicit defaults
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

    func applyPresetSelection(_ selection: PresetSelection) {
        switch selection {
        case .preset(let preset):
            selectPreset(preset)
        case .custom:
            presetSelection = .custom
        }
    }

    func selectPreset(_ preset: Preset) {
        presetSelection = .preset(preset)
        durationConfig = preset.durationConfig
    }

    func applyCustomDurationConfig(_ config: DurationConfig) {
        presetSelection = .custom
        durationConfig = config
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

    private enum DefaultsKey {
        static let notificationPreference = "notification.preference"
        static let reminderPreference = "notification.reminderPreference"
        static let dailyStats = "dailyStats.current"
    }

    private func saveNotificationPreference() {
        userDefaults.set(notificationPreference.rawValue, forKey: DefaultsKey.notificationPreference)
    }

    private func saveReminderPreference() {
        userDefaults.set(reminderPreference.rawValue, forKey: DefaultsKey.reminderPreference)
    }

    private static func loadDailyStats(from userDefaults: UserDefaults) -> DailyStats {
        guard let data = userDefaults.data(forKey: DefaultsKey.dailyStats) else {
            return DailyStats()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let stats = try? decoder.decode(DailyStats.self, from: data) {
            return stats
        }
        return DailyStats()
    }

    private func saveDailyStats(_ stats: DailyStats) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(stats) else { return }
        userDefaults.set(data, forKey: DefaultsKey.dailyStats)
    }

    private func requestNotificationAuthorizationIfNeeded() {
        guard notificationPreference != .off || reminderPreference != .off else { return }

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            guard settings.authorizationStatus == .notDetermined else { return }

            self.notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in
            }
        }
    }

    private func handlePomodoroRemaining(_ seconds: Int) {
        if seconds == 0 {
            if pomodoro.state == .running || pomodoro.state == .breakRunning {
                pomodoroDidReachZero = true
            }
            return
        }

        sendPomodoroReminderIfNeeded(remainingSeconds: seconds)
    }

    private func handlePomodoroStateChange(_ state: TimerState) {
        let previousState = lastPomodoroState ?? .idle

        switch state {
        case .running:
            if previousState == .idle {
                pomodoroDidReachZero = false
                pomodoroReminderSent = false
                currentFocusDurationSeconds = durationConfig.workDuration
                refreshDailyStatsForCurrentDay()
            }
        case .breakRunning:
            if previousState == .running || previousState == .paused {
                if pomodoroDidReachZero {
                    sendPomodoroCompletionNotification()
                    logFocusSessionIfNeeded()
                }
                pomodoroDidReachZero = false
            }

            if previousState != .breakPaused {
                pomodoroReminderSent = false
                currentBreakDurationSeconds = breakDurationSeconds(for: pomodoro.currentMode)
            }
            lastBreakMode = pomodoro.currentMode
        case .idle:
            if previousState == .breakRunning || previousState == .breakPaused {
                if pomodoroDidReachZero {
                    sendBreakCompletionNotification()
                    logBreakSessionIfNeeded()
                }
                pomodoroDidReachZero = false
            }
            currentBreakDurationSeconds = nil
            currentFocusDurationSeconds = nil
        case .paused, .breakPaused:
            break
        }

        lastPomodoroState = state
    }

    private func handleCountdownRemaining(_ seconds: Int) {
        if seconds == 0 {
            if countdown.state == .running {
                countdownDidReachZero = true
            }
            return
        }

        sendCountdownReminderIfNeeded(remainingSeconds: seconds)
    }

    private func handleCountdownStateChange(_ state: TimerState) {
        let previousState = lastCountdownState ?? .idle

        switch state {
        case .running:
            if previousState == .idle {
                countdownDidReachZero = false
                countdownReminderSent = false
            }
        case .idle:
            if previousState == .running || previousState == .paused {
                if countdownDidReachZero {
                    sendCountdownCompletionNotification()
                }
                countdownDidReachZero = false
            }
        case .paused, .breakRunning, .breakPaused:
            break
        }

        lastCountdownState = state
    }

    private func sendPomodoroReminderIfNeeded(remainingSeconds: Int) {
        let reminderLeadTime = reminderPreference.leadTimeSeconds
        guard reminderLeadTime > 0, !pomodoroReminderSent else { return }
        guard remainingSeconds == reminderLeadTime else { return }
        guard pomodoro.state == .running || pomodoro.state == .breakRunning else { return }

        let title = pomodoro.currentMode == .work ? "Pomodoro ending soon" : "Break ending soon"
        let body = "1 minute remaining."
        sendNotification(title: title, body: body)
        pomodoroReminderSent = true
    }

    private func sendCountdownReminderIfNeeded(remainingSeconds: Int) {
        let reminderLeadTime = reminderPreference.leadTimeSeconds
        guard reminderLeadTime > 0, !countdownReminderSent else { return }
        guard remainingSeconds == reminderLeadTime else { return }
        guard countdown.state == .running else { return }

        sendNotification(title: "Countdown ending soon", body: "1 minute remaining.")
        countdownReminderSent = true
    }

    private func sendPomodoroCompletionNotification() {
        sendNotification(title: "Pomodoro complete", body: "Time for a break.")
    }

    private func sendBreakCompletionNotification() {
        let title: String
        switch lastBreakMode {
        case .longBreak:
            title = "Long break complete"
        case .break:
            title = "Break complete"
        case .work, .idle, nil:
            title = "Break complete"
        }
        sendNotification(title: title, body: "Ready to focus again?")
    }

    private func sendCountdownCompletionNotification() {
        sendNotification(title: "Countdown complete", body: "Time is up.")
    }

    private func sendNotification(title: String, body: String) {
        guard notificationPreference != .off else { return }

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                if self.notificationPreference == .sound {
                    content.sound = .default
                }
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )
                self.notificationCenter.add(request)
            case .notDetermined:
                self.requestNotificationAuthorizationIfNeeded()
            case .denied, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    private func refreshDailyStatsForCurrentDay() {
        updateDailyStats { stats in
            stats.ensureCurrentDay()
        }
    }

    private func logFocusSessionIfNeeded() {
        guard let durationSeconds = currentFocusDurationSeconds else { return }
        updateDailyStats { stats in
            stats.logFocusSession(durationSeconds: durationSeconds)
        }
    }

    private func logBreakSessionIfNeeded() {
        guard let durationSeconds = currentBreakDurationSeconds else { return }
        updateDailyStats { stats in
            stats.logBreakSession(durationSeconds: durationSeconds)
        }
    }

    private func updateDailyStats(_ update: (inout DailyStats) -> Void) {
        var updatedStats = dailyStats
        update(&updatedStats)
        dailyStats = updatedStats
        saveDailyStats(updatedStats)
    }

    private func breakDurationSeconds(for mode: PomodoroTimerEngine.CurrentMode) -> Int? {
        switch mode {
        case .break:
            return durationConfig.shortBreakDuration
        case .longBreak:
            return durationConfig.longBreakDuration
        case .work, .idle:
            return nil
        }
    }
}
