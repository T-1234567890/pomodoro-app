//
//  MainWindowView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var musicController: MusicController
    @State private var workMinutesText = ""
    @State private var shortBreakMinutesText = ""
    @State private var longBreakMinutesText = ""
    @FocusState private var focusedField: DurationField?
    @State private var longBreakIntervalValue: Int = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(titleForPomodoroMode(appState.pomodoroMode))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(formattedTime(appState.pomodoro.remainingSeconds))
                    .font(.system(size: 48, weight: .semibold, design: .rounded).monospacedDigit())
                Text("State: \(labelForPomodoroState(appState.pomodoro.state))")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preset")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                Picker("Preset", selection: presetSelectionBinding) {
                    ForEach(Preset.builtIn) { preset in
                        Text(preset.name)
                            .tag(PresetSelection.preset(preset))
                    }
                    Text("Custom")
                        .tag(PresetSelection.custom)
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 10) {
                let actions = pomodoroActions(for: appState.pomodoro.state)
                ActionButton("Start", isEnabled: actions.canStart) {
                    appState.pomodoro.start()
                }
                ActionButton("Pause", isEnabled: actions.canPause) {
                    appState.pomodoro.pause()
                }
                ActionButton("Resume", isEnabled: actions.canResume) {
                    appState.pomodoro.resume()
                }
                ActionButton("Reset") {
                    appState.pomodoro.reset()
                }
                ActionButton("Skip Break", isEnabled: actions.canSkipBreak) {
                    appState.pomodoro.skipBreak()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Durations")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                DurationInputRow(
                    title: "Work",
                    text: $workMinutesText,
                    field: .work,
                    focusedField: $focusedField,
                    isFocused: focusedField == .work
                ) {
                    commitDuration(.work)
                }

                DurationInputRow(
                    title: "Short Break",
                    text: $shortBreakMinutesText,
                    field: .shortBreak,
                    focusedField: $focusedField,
                    isFocused: focusedField == .shortBreak
                ) {
                    commitDuration(.shortBreak)
                }

                DurationInputRow(
                    title: "Long Break",
                    text: $longBreakMinutesText,
                    field: .longBreak,
                    focusedField: $focusedField,
                    isFocused: focusedField == .longBreak
                ) {
                    commitDuration(.longBreak)
                }

                LongBreakIntervalRow(
                    interval: $longBreakIntervalValue
                ) {
                    updateDurationConfig(longBreakInterval: longBreakIntervalValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                Picker("Notifications", selection: $appState.notificationPreference) {
                    ForEach(NotificationPreference.allCases) { preference in
                        Text(preference.title)
                            .tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Reminder", selection: $appState.reminderPreference) {
                    ForEach(ReminderPreference.allCases) { preference in
                        Text(preference.title)
                            .tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ambient Sound")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                Picker("Ambient Sound", selection: ambientSoundBinding) {
                    ForEach(FocusSoundType.allCases) { sound in
                        Text(sound.displayName)
                            .tag(sound)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Countdown")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(formattedTime(appState.countdown.remainingSeconds))
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                Text("State: \(appState.countdown.state.rawValue.capitalized)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                let actions = countdownActions(for: appState.countdown.state)
                ActionButton("Start", isEnabled: actions.canStart) {
                    appState.countdown.start()
                }
                ActionButton("Pause", isEnabled: actions.canPause) {
                    appState.countdown.pause()
                }
                ActionButton("Resume", isEnabled: actions.canResume) {
                    appState.countdown.resume()
                }
                ActionButton("Reset") {
                    appState.countdown.reset()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Summary")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                summarySection
            }

            MediaControlBar()
                .environmentObject(appState.nowPlayingRouter)
        }
        .padding()
        .frame(minWidth: 360)
        .onAppear {
            syncDurationTexts()
            syncLongBreakInterval()
        }
        .onChange(of: appState.durationConfig) { _ in
            syncDurationTexts()
            syncLongBreakInterval()
        }
        .onChange(of: focusedField) { _, newValue in
            guard newValue == nil else { return }
            commitDuration(.work)
            commitDuration(.shortBreak)
            commitDuration(.longBreak)
        }
    }

    private var ambientSoundBinding: Binding<FocusSoundType> {
        Binding(
            get: { musicController.currentFocusSound },
            set: { newValue in
                if newValue == .off {
                    musicController.stopFocusSound()
                } else {
                    musicController.startFocusSound(newValue)
                }
            }
        )
    }

    private enum DurationField: Hashable {
        case work
        case shortBreak
        case longBreak
    }

    private struct DurationInputRow: View {
        let title: String
        @Binding var text: String
        let field: DurationField
        let focusedField: FocusState<DurationField?>.Binding
        let isFocused: Bool
        let onCommit: () -> Void

        var body: some View {
            HStack {
                Text(title)
                    .font(.system(.body, design: .rounded))
                Spacer()
                HStack(spacing: 6) {
                    TextField("", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .focused(focusedField, equals: field)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                        .onSubmit {
                            onCommit()
                        }
                    Text("min")
                        .foregroundStyle(.secondary)
                        .font(.system(.callout, design: .rounded))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) minutes")
            .accessibilityHint("Enter a number and press return")
        }
    }

    private struct LongBreakIntervalRow: View {
        @Binding var interval: Int
        let onCommit: () -> Void

        var body: some View {
            HStack {
                Text("Long Break Interval")
                    .font(.system(.body, design: .rounded))
                Spacer()
                Stepper(value: $interval, in: 1...12) {
                    Text("Every \(interval) sessions")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .onChange(of: interval) { _, _ in
                    onCommit()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Long break interval")
            .accessibilityHint("Choose how many work sessions before a long break")
        }
    }

    private struct ActionButton: View {
        let title: String
        let isEnabled: Bool
        let action: () -> Void
        @State private var isHovering = false

        init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.title = title
            self.isEnabled = isEnabled
            self.action = action
        }

        var body: some View {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.45)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering && isEnabled ? Color.accentColor.opacity(0.08) : .clear)
                )
                .onHover { hovering in
                    isHovering = hovering
                }
        }
    }

    private struct SummaryRow: View {
        let title: String
        let value: String

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .font(.system(.body, design: .rounded).monospacedDigit())
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let minutes = clampedSeconds / 60
        let remaining = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, remaining)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let hours = clampedSeconds / 3600
        let minutes = (clampedSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private enum SummaryState {
        case empty
        case stats(DailyStats)
    }

    private var summaryState: SummaryState {
        let stats = appState.dailyStats
        if stats.completedSessions == 0 && stats.totalFocusSeconds == 0 && stats.totalBreakSeconds == 0 {
            return .empty
        }
        return .stats(stats)
    }

    private var summarySection: some View {
        Group {
            switch summaryState {
            case .empty:
                Text("No sessions logged yet today.")
                    .foregroundStyle(.secondary)
                    .font(.system(.subheadline, design: .rounded))
            case .stats(let stats):
                VStack(alignment: .leading, spacing: 6) {
                    SummaryRow(title: "Focus time", value: formattedDuration(stats.totalFocusSeconds))
                    SummaryRow(title: "Break time", value: formattedDuration(stats.totalBreakSeconds))
                    SummaryRow(title: "Sessions", value: "\(stats.completedSessions)")
                }
            }
        }
    }

    private func labelForPomodoroState(_ state: TimerState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .breakRunning:
            return "Break (Running)"
        case .breakPaused:
            return "Break (Paused)"
        }
    }

    private func titleForPomodoroMode(_ mode: PomodoroTimerEngine.Mode) -> String {
        switch mode {
        case .work:
            return "Pomodoro"
        case .breakTime:
            return "Break"
        case .longBreak:
            return "Long Break"
        }
    }

    private struct PomodoroActionAvailability {
        let canStart: Bool
        let canPause: Bool
        let canResume: Bool
        let canSkipBreak: Bool
    }

    private struct CountdownActionAvailability {
        let canStart: Bool
        let canPause: Bool
        let canResume: Bool
    }

    private func pomodoroActions(for state: TimerState) -> PomodoroActionAvailability {
        switch state {
        case .idle:
            return PomodoroActionAvailability(
                canStart: true,
                canPause: false,
                canResume: false,
                canSkipBreak: false
            )
        case .running:
            return PomodoroActionAvailability(
                canStart: false,
                canPause: true,
                canResume: false,
                canSkipBreak: false
            )
        case .paused:
            return PomodoroActionAvailability(
                canStart: false,
                canPause: false,
                canResume: true,
                canSkipBreak: false
            )
        case .breakRunning:
            return PomodoroActionAvailability(
                canStart: false,
                canPause: true,
                canResume: false,
                canSkipBreak: true
            )
        case .breakPaused:
            return PomodoroActionAvailability(
                canStart: false,
                canPause: false,
                canResume: true,
                canSkipBreak: true
            )
        }
    }

    private func countdownActions(for state: TimerState) -> CountdownActionAvailability {
        switch state {
        case .idle:
            return CountdownActionAvailability(canStart: true, canPause: false, canResume: false)
        case .running:
            return CountdownActionAvailability(canStart: false, canPause: true, canResume: false)
        case .paused:
            return CountdownActionAvailability(canStart: false, canPause: false, canResume: true)
        case .breakRunning, .breakPaused:
            return CountdownActionAvailability(canStart: false, canPause: false, canResume: false)
        }
    }

    private var workMinutesValue: Int {
        max(1, appState.durationConfig.workDuration / 60)
    }

    private var shortBreakMinutesValue: Int {
        max(1, appState.durationConfig.shortBreakDuration / 60)
    }

    private var longBreakMinutesValue: Int {
        max(1, appState.durationConfig.longBreakDuration / 60)
    }

    private func updateDurationConfig(
        workMinutes: Int? = nil,
        shortBreakMinutes: Int? = nil,
        longBreakMinutes: Int? = nil,
        longBreakInterval: Int? = nil
    ) {
        let currentConfig = appState.durationConfig
        let updatedWorkMinutes = clamp(workMinutes ?? currentConfig.workDuration / 60, range: 1...120)
        let updatedShortBreakMinutes = clamp(shortBreakMinutes ?? currentConfig.shortBreakDuration / 60, range: 1...60)
        let updatedLongBreakMinutes = clamp(longBreakMinutes ?? currentConfig.longBreakDuration / 60, range: 1...90)
        let updatedLongBreakInterval = clamp(longBreakInterval ?? currentConfig.longBreakInterval, range: 1...12)

        appState.applyCustomDurationConfig(DurationConfig(
            workDuration: updatedWorkMinutes * 60,
            shortBreakDuration: updatedShortBreakMinutes * 60,
            longBreakDuration: updatedLongBreakMinutes * 60,
            longBreakInterval: updatedLongBreakInterval
        ))
    }

    private var presetSelectionBinding: Binding<PresetSelection> {
        Binding(
            get: { appState.presetSelection },
            set: { appState.applyPresetSelection($0) }
        )
    }

    private func syncDurationTexts() {
        if focusedField != .work {
            workMinutesText = String(workMinutesValue)
        }
        if focusedField != .shortBreak {
            shortBreakMinutesText = String(shortBreakMinutesValue)
        }
        if focusedField != .longBreak {
            longBreakMinutesText = String(longBreakMinutesValue)
        }
    }

    private func syncLongBreakInterval() {
        longBreakIntervalValue = clamp(appState.durationConfig.longBreakInterval, range: 1...12)
    }

    private func commitDuration(_ field: DurationField) {
        switch field {
        case .work:
            let committed = parseMinutes(from: workMinutesText, fallback: workMinutesValue, range: 1...120)
            workMinutesText = String(committed)
            updateDurationConfig(workMinutes: committed)
        case .shortBreak:
            let committed = parseMinutes(from: shortBreakMinutesText, fallback: shortBreakMinutesValue, range: 1...60)
            shortBreakMinutesText = String(committed)
            updateDurationConfig(shortBreakMinutes: committed)
        case .longBreak:
            let committed = parseMinutes(from: longBreakMinutesText, fallback: longBreakMinutesValue, range: 1...90)
            longBreakMinutesText = String(committed)
            updateDurationConfig(longBreakMinutes: committed)
        }
    }

    private func parseMinutes(from text: String, fallback: Int, range: ClosedRange<Int>) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else {
            return clamp(fallback, range: range)
        }
        return clamp(value, range: range)
    }

    private func clamp(_ value: Int, range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

#Preview {
    let appState = AppState()
    MainWindowView()
        .environmentObject(appState)
        .environmentObject(MusicController(ambientNoiseEngine: appState.ambientNoiseEngine))
}
