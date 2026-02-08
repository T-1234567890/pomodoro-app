//
//  MainWindowView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import EventKit
import SwiftUI
import UserNotifications
import Charts

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var musicController: MusicController
    @EnvironmentObject private var audioSourceStore: AudioSourceStore
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
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var calendarStatus: EKAuthorizationStatus = .notDetermined
    @State private var remindersStatus: EKAuthorizationStatus = .notDetermined
    private let sessionRecordStore = SessionRecordStore.shared
    @State private var weeklyFocusPoints: [DailyFocusPoint] = []
    @State private var todayFocusMinutes: Int = 0
    @State private var completionRate: Double = 0
    private let eventStore = EKEventStore()
    @State private var lastNonFlowSelection: SidebarItem = .pomodoro
    // Slider micro-interactions
    @State private var ambientSliderEditing = false
    @State private var ambientSliderHover = false
    @State private var systemSliderHover = false
    
    // New: Calendar, Reminders, and Todo system
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var todoStore = TodoStore()
    @StateObject private var planningStore = PlanningStore()
    @StateObject private var remindersSync = RemindersSync(permissionsManager: PermissionsManager.shared)
    @StateObject private var calendarManager = CalendarManager(permissionsManager: PermissionsManager.shared)

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
                todoStore.attachPlanningStore(planningStore)
                remindersSync.setTodoStore(todoStore)
            }
            .onChange(of: appState.durationConfig) { _, _ in
                syncDurationTexts()
                syncLongBreakInterval()
            }
            .onChange(of: sidebarSelection) { _, newValue in
                if newValue != .flow {
                    lastNonFlowSelection = newValue
                    appState.isInFlowMode = false
                } else {
                    appState.isInFlowMode = true
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .navigateToFlow)) { _ in
                withAnimation {
                    sidebarSelection = .flow
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToTasks)) { _ in
                withAnimation {
                    sidebarSelection = .tasks
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToCalendar)) { _ in
                withAnimation {
                    sidebarSelection = .calendar
                }
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
        // macOS 26 adds an opaque toolbar strip; hide that layer so the wallpaper blur flows
        // into the title bar while keeping native window controls intact.
        .toolbarBackground(.hidden, for: .windowToolbar)
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
            case .flow:
                flowModeView
            case .countdown:
                countdownView
            case .tasks:
                tasksView
            case .calendar:
                calendarView
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
                    .contentTransition(.numericText())
                    // Flow-mode-inspired gentle tick dissolve to keep time feeling fluid.
                    .animation(mainTimerUpdateAnimation, value: appState.pomodoro.remainingSeconds)
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

    private var flowModeView: some View {
        FlowModeView(exitAction: {
            withAnimation {
                sidebarSelection = lastNonFlowSelection
            }
        })
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
                    .contentTransition(.numericText())
                    .animation(mainTimerUpdateAnimation, value: appState.countdown.remainingSeconds)
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
    
    private var tasksView: some View {
        TodoListView(
            todoStore: todoStore,
            planningStore: planningStore,
            remindersSync: remindersSync,
            permissionsManager: permissionsManager
        )
    }

    private var calendarView: some View {
        CalendarView(
            calendarManager: calendarManager,
            permissionsManager: permissionsManager,
            todoStore: todoStore
        )
    }

    private var audioAndMusicView: some View {
        VStack(alignment: .leading, spacing: 16) {
            nowPlayingSection
            Divider()
                .padding(.vertical, 4)
            sourceSelector
        }
        .padding(.top, 28)
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 360, alignment: .leading)
    }

    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .center, spacing: 8) {
                    Text("Today's Summary")
                        .font(.system(size: 22, weight: .semibold, design: .default))
                        .foregroundStyle(.secondary)
                    summarySection
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                summaryFocusTiles
                weeklyFocusChart
                completionSection
            }
            .padding(.top, 28)
            .padding(.horizontal)
            .padding(.bottom)
            .frame(minWidth: 360, alignment: .leading)
        }
        .onAppear {
            refreshSummaryMetrics()
        }
        .onChange(of: todoStore.items) { _, _ in
            refreshSummaryMetrics()
        }
    }

    private var settingsView: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            // Subtle overlay to keep text legible while showing wallpaper blur
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.32)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSectionCard(title: "Notifications") {
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

                    SettingsSectionCard(title: "Permissions & Sync") {
                        SettingsView(permissionsManager: permissionsManager)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                .padding(.trailing, 8) // keep scrollbar off the content edge
                .frame(maxWidth: 820, alignment: .leading)
            }
        }
        .frame(minWidth: 520, idealWidth: 680, maxWidth: 900, minHeight: 520, alignment: .topLeading)
        .onAppear {
            refreshPermissionStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatuses()
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openCalendarSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openRemindersSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") else { return }
        NSWorkspace.shared.open(url)
    }

    private func handleNotificationAccessRequest() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    refreshPermissionStatuses()
                }
            }
            DispatchQueue.main.async {
                openNotificationSettings()
            }
        }
    }

    private func handleCalendarAccessRequest() {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarStatus = status
        if status == .notDetermined {
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { _, _ in
                    DispatchQueue.main.async {
                        refreshPermissionStatuses()
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { _, _ in
                    DispatchQueue.main.async {
                        refreshPermissionStatuses()
                    }
                }
            }
        }
        openCalendarSettings()
    }

    // MARK: - Audio UI

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now Playing")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)

            switch audioSourceStore.audioSource {
            case .external(let media):
                HStack(alignment: .center, spacing: 14) {
                    externalArtwork(media)
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(media.title)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                        Text(media.artist)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(media.source.displayName)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        audioSourceStore.togglePlayPause()
                    } label: {
                        Image(systemName: "playpause.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Volume (system)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: .constant(Double(musicController.focusVolume)), in: 0...1, onEditingChanged: { _ in })
                            .disabled(true)
                            // Soft hover feedback without altering layout or color palette.
                            .opacity(systemSliderHover ? 1.0 : 0.92)
                            .onHover { hovering in
                                if reduceMotion {
                                    systemSliderHover = hovering
                                } else {
                                    withAnimation(.easeOut(duration: 0.18)) { systemSliderHover = hovering }
                                }
                            }
                    }
                    .frame(width: 200)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

            case .ambient(let type):
                HStack(alignment: .center, spacing: 14) {
                    ambientIcon(for: type)
                        .font(.system(size: 30, weight: .semibold))
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.displayName)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                        Text("Ambient · Local")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        audioSourceStore.togglePlayPause()
                    } label: {
                        Image(systemName: musicController.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: ambientVolumeBinding, in: 0...1, onEditingChanged: { editing in
                            if reduceMotion {
                                ambientSliderEditing = editing
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) { ambientSliderEditing = editing }
                            }
                        })
                        // Smooth fill animation to avoid abrupt jumps.
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: musicController.focusVolume)
                        // Tactile scale while dragging; small enough to avoid layout shift.
                        .scaleEffect(ambientSliderEditing ? 1.03 : 1.0, anchor: .center)
                        // Subtle hover lift in line with macOS controls.
                        .opacity((ambientSliderHover || ambientSliderEditing) ? 1.0 : 0.95)
                        .onHover { hovering in
                            if reduceMotion {
                                ambientSliderHover = hovering
                            } else {
                                withAnimation(.easeOut(duration: 0.18)) { ambientSliderHover = hovering }
                            }
                        }
                    }
                    .frame(width: 200)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

            case .off:
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "waveform")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("No audio playing")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                        Text("Start Apple Music, Spotify, or select an ambient sound")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    private var sourceSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audio Source")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                selectorButton(
                    title: "External",
                    isActive: externalActive,
                    isDisabled: !externalActive,
                    action: { }
                )

                ForEach(FocusSoundType.allCases.filter { $0 != .off }, id: \.self) { type in
                    selectorButton(
                        title: type.displayName,
                        isActive: currentAmbient == type,
                        isDisabled: externalActive,
                        action: { audioSourceStore.selectAmbient(type) }
                    )
                }
            }
        }
    }

    private func selectorButton(title: String, isActive: Bool, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(isActive ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? Color.accentColor : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1.0)
    }

    private var ambientVolumeBinding: Binding<Double> {
        Binding(
            get: { Double(musicController.focusVolume) },
            set: { newValue in
                audioSourceStore.setVolume(Float(newValue))
            }
        )
    }

    private var externalActive: Bool {
        if case .external = audioSourceStore.audioSource { return true }
        return false
    }

    private var currentAmbient: FocusSoundType? {
        if case .ambient(let type) = audioSourceStore.audioSource {
            return type
        }
        return nil
    }

    @ViewBuilder
    private func externalArtwork(_ media: ExternalMedia) -> some View {
        if let artwork = media.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func ambientIcon(for type: FocusSoundType) -> Image {
        switch type {
        case .white, .off:
            return Image(systemName: "waveform")
        case .brown:
            return Image(systemName: "wind")
        case .rain:
            return Image(systemName: "cloud.rain")
        case .wind:
            return Image(systemName: "wind.circle")
        }
    }

    private func handleRemindersAccessRequest() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        remindersStatus = status
        if status == .notDetermined {
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToReminders { _, _ in
                    DispatchQueue.main.async {
                        refreshPermissionStatuses()
                    }
                }
            } else {
                eventStore.requestAccess(to: .reminder) { _, _ in
                    DispatchQueue.main.async {
                        refreshPermissionStatuses()
                    }
                }
            }
        }
        openRemindersSettings()
    }

    private func refreshPermissionStatuses() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    private func permissionStatusRow(title: String, statusText: String, statusColor: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text("\(title): \(statusText)")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func notificationStatusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    private func notificationStatusColor(_ status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private func eventStatusText(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .fullAccess:
            return "Full Access"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }

    private func eventStatusColor(_ status: EKAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private enum DurationField: Hashable {
        case work
        case shortBreak
        case longBreak
        case countdown
    }

    private enum SidebarItem: String, CaseIterable, Identifiable {
        case pomodoro
        case flow
        case countdown
        case tasks
        case calendar
        case audioAndMusic
        case summary
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pomodoro:
                return "Pomodoro"
            case .flow:
                return "Flow"
            case .countdown:
                return "Countdown"
            case .tasks:
                return "Tasks"
            case .calendar:
                return "Calendar"
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
            case .flow:
                return "circle.dotted"
            case .countdown:
                return "hourglass"
            case .tasks:
                return "checklist"
            case .calendar:
                return "calendar"
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
        @GestureState private var isPressing = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .scaleEffect(pressScale)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering && isEnabled ? Color.accentColor.opacity(0.08) : .clear)
                )
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isHovering)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isPressing)
                .onHover { hovering in
                    isHovering = hovering
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isPressing) { _, state, _ in state = true }
                )
        }

        private var pressScale: CGFloat {
            guard isEnabled, !reduceMotion else { return 1.0 }
            return isPressing ? 0.98 : 1.0
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

    private var summaryFocusTiles: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's Focus")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(todayFocusMinutes)m")
                    .font(.title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Completion")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(Int(completionRate * 100))%")
                    .font(.title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(10)
        }
    }
    
    private var weeklyFocusChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Focus Trend")
                .font(.headline)
                .foregroundStyle(.secondary)
            Chart(weeklyFocusPoints) { point in
                BarMark(
                    x: .value("Day", shortWeekdayFormatter.string(from: point.date)),
                    y: .value("Minutes", point.minutes)
                )
            }
            .frame(height: 180)
        }
    }
    
    private var completionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Completion")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if todoStore.items.isEmpty {
                Text("No tasks yet.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                let completedCount = todoStore.items.filter { $0.isCompleted }.count
                let total = todoStore.items.count
                let activeCount = max(0, total - completedCount)
                
                // Option A: Split into two clear sections to avoid scale imbalance.
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Completion Overview")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(completedCount) completed")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    // Subtle material + tint to feel native and avoid heavy color blocks.
                    .background(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.08))
                    )
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Load")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(activeCount) active")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cyan.opacity(0.08))
                    )
                    .cornerRadius(10)
                }
            }
        }
    }

    private var shortWeekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }

    private func refreshSummaryMetrics() {
        let calendar = Calendar.current
        let todayRecords = sessionRecordStore.records(for: Date(), calendar: calendar)
        todayFocusMinutes = todayRecords.reduce(0) { $0 + max(0, $1.durationSeconds) } / 60
        
        let sevenDayRecords = sessionRecordStore.records(lastDays: 7, calendar: calendar)
        let grouped = Dictionary(grouping: sevenDayRecords) { calendar.startOfDay(for: $0.startTime) }
        let lastSevenDays = (0..<7).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date()))
        }.reversed()
        weeklyFocusPoints = lastSevenDays.map { day in
            let totalSeconds = grouped[day]?.reduce(0) { $0 + $1.durationSeconds } ?? 0
            return DailyFocusPoint(date: day, minutes: totalSeconds / 60)
        }
        
        let totalTasks = todoStore.items.count
        let completed = todoStore.items.filter { $0.isCompleted }.count
        completionRate = totalTasks == 0 ? 0 : Double(completed) / Double(totalTasks)
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

    private struct DailyFocusPoint: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Int
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
        // Calm, lightweight easing for state transitions and numeric pulse.
        reduceMotion ? nil : .easeOut(duration: 0.22)
    }
    
    private var mainTimerUpdateAnimation: Animation? {
        // Subtle dissolve for ticking seconds; keeps the timer feeling fluid.
        reduceMotion ? nil : .easeOut(duration: 0.14)
    }

    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        // Calm fade + slight scale keeps transitions lightweight; avoids sliding motion.
        let fadeScale = AnyTransition.opacity.combined(with: .scale(scale: 0.985))
        return .asymmetric(insertion: fadeScale, removal: fadeScale)
    }

    private var sectionTransitionAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.22)
    }

    private func shouldAnimateTimerTransition(from oldValue: TimerState, to newValue: TimerState) -> Bool {
        if oldValue == .idle && newValue == .running {
            return true
        }
        if oldValue == .running && newValue == .paused {
            return true
        }
        if oldValue == .paused && newValue == .running {
            return true
        }
        if oldValue == .running && (newValue == .breakRunning || newValue == .breakPaused) {
            return true
        }
        if oldValue == .breakPaused && newValue == .breakRunning {
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

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Menu bar navigation hooks
extension Notification.Name {
    static let navigateToFlow = Notification.Name("navigateToFlow")
    static let navigateToTasks = Notification.Name("navigateToTasks")
    static let navigateToCalendar = Notification.Name("navigateToCalendar")
}

#if DEBUG && PREVIEWS_ENABLED
#Preview {
    let appState = AppState()
    let musicController = MusicController(ambientNoiseEngine: appState.ambientNoiseEngine)
    let audioSourceStore = MainActor.assumeIsolated {
        let externalMonitor = ExternalAudioMonitor()
        let externalController = ExternalPlaybackController()
        AudioSourceStore(
            musicController: musicController,
            externalMonitor: externalMonitor,
            externalController: externalController
        )
    }
    MainWindowView()
        .environmentObject(appState)
        .environmentObject(musicController)
        .environmentObject(audioSourceStore)
}
#endif
