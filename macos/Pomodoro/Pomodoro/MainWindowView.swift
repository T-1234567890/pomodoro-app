//
//  MainWindowView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import EventKit
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var musicController: MusicController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var workMinutesText = ""
    @State private var shortBreakMinutesText = ""
    @State private var longBreakMinutesText = ""
    @State private var countdownMinutesText = ""
    @FocusState private var focusedField: DurationField?
    @State private var longBreakIntervalValue: Int = 4
    @State private var sidebarSelection: SidebarItem = .pomodoro
    @State private var pomodoroStatePulse = false
    @State private var countdownStatePulse = false
    private let eventStore = EKEventStore()

    var body: some View {
        ZStack(alignment: .top) {
            // Real macOS wallpaper blur using NSVisualEffectView
            // This replaces the failed Rectangle().fill(.ultraThinMaterial) approach because:
            // - SwiftUI Material is a compositing effect, not true vibrancy
            // - It cannot access the desktop wallpaper layer
            // - NSVisualEffectView with .behindWindow blending is required for wallpaper blur
            // Note: Individual UI components (popups, buttons) may still use .ultraThinMaterial
            // for layered glass effects on top of this main background blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            NavigationSplitView {
                sidebar
            } detail: {
                detailView
            }
            .navigationSplitViewStyle(.balanced)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
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
                commitDuration(.countdown)
            }
            .onChange(of: appState.pomodoro.state) { oldValue, newValue in
                triggerPomodoroStateAnimation(from: oldValue, to: newValue)
            }
            .onChange(of: appState.countdown.state) { oldValue, newValue in
                triggerCountdownStateAnimation(from: oldValue, to: newValue)
            }

            if appState.transitionPopup != nil || appState.notificationPopup != nil {
                VStack(spacing: 8) {
                    if let popup = appState.transitionPopup {
                        TransitionPopupView(message: popup.message)
                    }
                    if let popup = appState.notificationPopup {
                        InAppNotificationView(title: popup.title, message: popup.body)
                    }
                }
                .padding(.top, 12)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
                .allowsHitTesting(false)
            }
        }
        .background(WindowBackgroundConfigurator())
        .animation(reduceMotion ? .linear(duration: 0.2) : .easeInOut(duration: 0.25),
                   value: appState.transitionPopup?.id)
        .animation(reduceMotion ? .linear(duration: 0.2) : .easeInOut(duration: 0.25),
                   value: appState.notificationPopup?.id)
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
    }

    private var detailView: some View {
        ZStack {
            switch sidebarSelection {
            case .pomodoro:
                pomodoroView
            case .countdown:
                countdownView
            case .audioAndMusic:
                audioAndMusicView
            case .summary:
                summaryView
            case .settings:
                settingsView
            }
        }
        .id(sidebarSelection)
        .transition(sectionTransition)
        .animation(sectionTransitionAnimation, value: sidebarSelection)
    }

    private var pomodoroView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(titleForPomodoroMode(appState.pomodoroMode))
                    .font(.system(.headline, design: .default))
                    .foregroundStyle(.secondary)
                Text(formattedTime(appState.pomodoro.remainingSeconds))
                    .font(.system(size: 72, weight: .heavy, design: .default).monospacedDigit())
                    .scaleEffect(pomodoroStatePulse ? 1.0 : 0.98)
                    .opacity(pomodoroStatePulse ? 1.0 : 0.94)
                    .animation(timerStateAnimation, value: pomodoroStatePulse)
                Text("State: \(labelForPomodoroState(appState.pomodoro.state))")
                    .font(.system(size: 15, weight: .medium, design: .default))
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
        }
        .padding(.top, 28)
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 360, alignment: .leading)
    }

    private var countdownView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Countdown")
                    .font(.system(.headline, design: .default))
                    .foregroundStyle(.secondary)
                Text(formattedTime(appState.countdown.remainingSeconds))
                    .font(.system(size: 72, weight: .heavy, design: .default).monospacedDigit())
                    .scaleEffect(countdownStatePulse ? 1.0 : 0.98)
                    .opacity(countdownStatePulse ? 1.0 : 0.94)
                    .animation(timerStateAnimation, value: countdownStatePulse)
                Text("State: \(appState.countdown.state.rawValue.capitalized)")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                DurationInputRow(
                    title: "Countdown",
                    text: $countdownMinutesText,
                    field: .countdown,
                    focusedField: $focusedField,
                    isFocused: focusedField == .countdown
                ) {
                    commitDuration(.countdown)
                }
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
        }
        .padding(.top, 28)
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 360, alignment: .leading)
    }

    private var audioAndMusicView: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            MediaControlBar()
                .environmentObject(appState.nowPlayingRouter)
        }
        .padding(.top, 28)
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 360, alignment: .leading)
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .center, spacing: 8) {
                Text("Today's Summary")
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(.secondary)
                summarySection
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 28)
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 360, alignment: .leading)
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                Picker("Delivery", selection: $appState.notificationDeliveryStyle) {
                    ForEach(NotificationDeliveryStyle.allCases) { style in
                        Text(style.title)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)

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
                Text("Quick Actions")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Request Notifications") {
                        appState.requestSystemNotificationAuthorization { _ in }
                    }
                    .buttonStyle(.bordered)

                    Button("Open Notification Settings") {
                        openNotificationSettings()
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    Button("Get Calendar Access") {
                        requestCalendarAccess()
                    }
                    .buttonStyle(.bordered)

                    Button("Get Reminders Access") {
                        requestRemindersAccess()
                    }
                    .buttonStyle(.bordered)
                }
            }

        }
        .padding(.top, 28)
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 360, alignment: .leading)
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

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestCalendarAccess() {
        eventStore.requestAccess(to: .event) { _, _ in }
    }

    private func requestRemindersAccess() {
        eventStore.requestAccess(to: .reminder) { _, _ in }
    }

    private enum DurationField: Hashable {
        case work
        case shortBreak
        case longBreak
        case countdown
    }

    private enum SidebarItem: String, CaseIterable, Identifiable {
        case pomodoro
        case countdown
        case audioAndMusic
        case summary
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pomodoro:
                return "Pomodoro"
            case .countdown:
                return "Countdown"
            case .audioAndMusic:
                return "Audio&Music"
            case .summary:
                return "Summary"
            case .settings:
                return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .pomodoro:
                return "timer"
            case .countdown:
                return "hourglass"
            case .audioAndMusic:
                return "music.note.list"
            case .summary:
                return "chart.bar"
            case .settings:
                return "gearshape"
            }
        }
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

    private struct TransitionPopupView: View {
        let message: String

        var body: some View {
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
    }

    private struct InAppNotificationView: View {
        let title: String
        let message: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
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

    private var countdownMinutesValue: Int {
        max(1, appState.durationConfig.countdownDuration / 60)
    }

    private func updateDurationConfig(
        workMinutes: Int? = nil,
        shortBreakMinutes: Int? = nil,
        longBreakMinutes: Int? = nil,
        longBreakInterval: Int? = nil,
        countdownMinutes: Int? = nil
    ) {
        let currentConfig = appState.durationConfig
        let updatedWorkMinutes = clamp(workMinutes ?? currentConfig.workDuration / 60, range: 1...120)
        let updatedShortBreakMinutes = clamp(shortBreakMinutes ?? currentConfig.shortBreakDuration / 60, range: 1...60)
        let updatedLongBreakMinutes = clamp(longBreakMinutes ?? currentConfig.longBreakDuration / 60, range: 1...90)
        let updatedLongBreakInterval = clamp(longBreakInterval ?? currentConfig.longBreakInterval, range: 1...12)
        let updatedCountdownMinutes = clamp(countdownMinutes ?? currentConfig.countdownDuration / 60, range: 1...120)

        appState.applyCustomDurationConfig(DurationConfig(
            workDuration: updatedWorkMinutes * 60,
            shortBreakDuration: updatedShortBreakMinutes * 60,
            longBreakDuration: updatedLongBreakMinutes * 60,
            longBreakInterval: updatedLongBreakInterval,
            countdownDuration: updatedCountdownMinutes * 60
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
        if focusedField != .countdown {
            countdownMinutesText = String(countdownMinutesValue)
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
        case .countdown:
            let committed = parseMinutes(from: countdownMinutesText, fallback: countdownMinutesValue, range: 1...120)
            countdownMinutesText = String(committed)
            updateDurationConfig(countdownMinutes: committed)
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

    private var timerStateAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        let insertion = AnyTransition.opacity.combined(with: .offset(x: 8, y: 0))
        let removal = AnyTransition.opacity.combined(with: .offset(x: -8, y: 0))
        return .asymmetric(insertion: insertion, removal: removal)
    }

    private var sectionTransitionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.15)
    }

    private func shouldAnimateTimerTransition(from oldValue: TimerState, to newValue: TimerState) -> Bool {
        if oldValue == .idle && newValue == .running {
            return true
        }
        if oldValue == .running && newValue == .paused {
            return true
        }
        if oldValue == .running && (newValue == .breakRunning || newValue == .breakPaused) {
            return true
        }
        if (oldValue == .breakRunning || oldValue == .breakPaused) && newValue == .idle {
            return true
        }
        if oldValue != .idle && newValue == .idle {
            return true
        }
        return false
    }

    private func triggerPomodoroStateAnimation(from oldValue: TimerState, to newValue: TimerState) {
        guard shouldAnimateTimerTransition(from: oldValue, to: newValue), !reduceMotion else { return }
        pomodoroStatePulse.toggle()
    }

    private func triggerCountdownStateAnimation(from oldValue: TimerState, to newValue: TimerState) {
        guard shouldAnimateTimerTransition(from: oldValue, to: newValue), !reduceMotion else { return }
        countdownStatePulse.toggle()
    }
}

#if DEBUG && PREVIEWS_ENABLED
#Preview {
    let appState = AppState()
    MainWindowView()
        .environmentObject(appState)
        .environmentObject(MusicController(ambientNoiseEngine: appState.ambientNoiseEngine))
}
#endif
