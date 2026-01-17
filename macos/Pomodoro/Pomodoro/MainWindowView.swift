//
//  MainWindowView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var workMinutesText = ""
    @State private var shortBreakMinutesText = ""
    @State private var longBreakMinutesText = ""
    @FocusState private var focusedField: DurationField?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(titleForPomodoroMode(appState.pomodoroMode))
                    .font(.headline)
                Text(formattedTime(appState.pomodoro.remainingSeconds))
                    .font(.title)
                Text("State: \(labelForPomodoroState(appState.pomodoro.state))")
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preset")
                    .font(.headline)
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

            HStack(spacing: 12) {
                Button("Start") {
                    appState.pomodoro.start()
                }
                .disabled(!pomodoroActions(for: appState.pomodoro.state).canStart)
                Button("Pause") {
                    appState.pomodoro.pause()
                }
                .disabled(!pomodoroActions(for: appState.pomodoro.state).canPause)
                Button("Resume") {
                    appState.pomodoro.resume()
                }
                .disabled(!pomodoroActions(for: appState.pomodoro.state).canResume)
                Button("Reset") {
                    appState.pomodoro.reset()
                }
                Button("Skip Break") {
                    appState.pomodoro.skipBreak()
                }
                .disabled(!pomodoroActions(for: appState.pomodoro.state).canSkipBreak)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Durations")
                    .font(.headline)
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
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Countdown")
                    .font(.headline)
                Text(formattedTime(appState.countdown.remainingSeconds))
                    .font(.title)
                Text("State: \(appState.countdown.state.rawValue.capitalized)")
                    .font(.subheadline)
            }

            HStack(spacing: 12) {
                Button("Start") {
                    appState.countdown.start()
                }
                .disabled(!countdownActions(for: appState.countdown.state).canStart)
                Button("Pause") {
                    appState.countdown.pause()
                }
                .disabled(!countdownActions(for: appState.countdown.state).canPause)
                Button("Resume") {
                    appState.countdown.resume()
                }
                .disabled(!countdownActions(for: appState.countdown.state).canResume)
                Button("Reset") {
                    appState.countdown.reset()
                }
            }
        }
        .padding()
        .frame(minWidth: 360)
        .onAppear {
            syncDurationTexts()
        }
        .onChange(of: appState.durationConfig) { _ in
            syncDurationTexts()
        }
        .onChange(of: focusedField) { _, newValue in
            guard newValue == nil else { return }
            commitDuration(.work)
            commitDuration(.shortBreak)
            commitDuration(.longBreak)
        }
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
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) minutes")
            .accessibilityHint("Enter a number and press return")
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let minutes = clampedSeconds / 60
        let remaining = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, remaining)
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
        longBreakMinutes: Int? = nil
    ) {
        let currentConfig = appState.durationConfig
        let updatedWorkMinutes = clamp(workMinutes ?? currentConfig.workDuration / 60, range: 1...120)
        let updatedShortBreakMinutes = clamp(shortBreakMinutes ?? currentConfig.shortBreakDuration / 60, range: 1...60)
        let updatedLongBreakMinutes = clamp(longBreakMinutes ?? currentConfig.longBreakDuration / 60, range: 1...90)

        appState.applyCustomDurationConfig(DurationConfig(
            workDuration: updatedWorkMinutes * 60,
            shortBreakDuration: updatedShortBreakMinutes * 60,
            longBreakDuration: updatedLongBreakMinutes * 60,
            longBreakInterval: currentConfig.longBreakInterval
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
    MainWindowView()
        .environmentObject(AppState())
}
