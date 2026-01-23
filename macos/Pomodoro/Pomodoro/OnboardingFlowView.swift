//
//  OnboardingFlowView.swift
//  Pomodoro
//
//  Created by OpenAI on 2025-02-01.
//

import AppKit
import SwiftUI
import UserNotifications

struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var onboardingState: OnboardingState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flow: [OnboardingStep] = []
    @State private var index: Int = 0
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingAuthorization = false

    private var step: OnboardingStep {
        guard index < flow.count else { return .welcome }
        return flow[index]
    }

    private var isLastStep: Bool {
        index == flow.count - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(step.title)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                Spacer()
                Button("Not Now") {
                    onboardingState.markCompleted()
                }
                .buttonStyle(.borderless)
            }

            stepContent

            Spacer()

            HStack {
                if index > 0 {
                    Button("Back") {
                        back()
                    }
                }
                Spacer()
                Button(isLastStep ? "Finish" : "Continue") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 520, height: 360)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: step)
        .onAppear {
            rebuildFlow()
            refreshAuthorizationStatusIfNeeded()
        }
        .onChange(of: step) { _, _ in
            refreshAuthorizationStatusIfNeeded()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            VStack(alignment: .leading, spacing: 12) {
                Text("Pomodoro helps you focus with structured work and break sessions.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        case .notificationStyle:
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose how you want to be notified when sessions end.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)

                Picker("Notification Style", selection: $appState.notificationDeliveryStyle) {
                    ForEach(NotificationDeliveryStyle.allCases) { style in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.title)
                            Text(style.detail)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        case .notificationPermission:
            VStack(alignment: .leading, spacing: 12) {
                Text("Pomodoro can notify you when sessions end.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)

                statusRow

                HStack(spacing: 12) {
                    Button(isRequestingAuthorization ? "Requesting..." : "Enable Notifications") {
                        requestAuthorization()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRequestingAuthorization)

                    if authorizationStatus == .denied {
                        Button("Open System Settings") {
                            openNotificationSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        case .media:
            VStack(alignment: .leading, spacing: 12) {
                Text("Audio & Music")
                    .font(.system(.headline, design: .rounded))
                Text("Pomodoro includes built-in focus sounds that work without any permission.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Optional Apple Music or Spotify integration is possible later using their official SDKs.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        case .systemPermissions:
            VStack(alignment: .leading, spacing: 12) {
                Text("Calendar & Reminders")
                    .font(.system(.headline, design: .rounded))
                Text("Enable read-only calendar context and optional reminders to link with focus sessions. You can skip and enable later.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Enable Access") {
                        Task {
                            isRequestingAuthorization = true
                            await appState.requestCalendarAndReminderAccessIfNeeded()
                            isRequestingAuthorization = false
                            onboardingState.markPermissionsPrompted()
                            advance()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingAuthorization)

                    Button("Not Now") {
                        onboardingState.markPermissionsPrompted()
                        advance()
                    }
                    .buttonStyle(.bordered)
                }

                Text(appState.calendarReminderPermissionStatusText)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        case .menuBarTip:
            VStack(alignment: .leading, spacing: 12) {
                Text("Menu Bar Tip")
                    .font(.system(.headline, design: .rounded))
                Text("Pomodoro lives in your macOS menu bar. Hold Command (⌘) and drag icons to reorder, including Pomodoro.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)

                Button("Got it") {
                    onboardingState.markMenuBarTipSeen()
                    advance()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        switch authorizationStatus {
        case .authorized, .provisional:
            return "Notifications are enabled."
        case .denied:
            return "Notifications are turned off in System Settings."
        case .notDetermined:
            return "Notifications have not been requested yet."
        case .ephemeral:
            return "Notifications are temporarily available."
        @unknown default:
            return "Notification status unavailable."
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .ephemeral:
            return .blue
        @unknown default:
            return .gray
        }
    }

    private func refreshAuthorizationStatusIfNeeded() {
        guard step == .notificationPermission else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                authorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestAuthorization() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        appState.requestSystemNotificationAuthorization { status in
            authorizationStatus = status
            isRequestingAuthorization = false
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    private func advance() {
        guard !flow.isEmpty else {
            onboardingState.markCompleted()
            return
        }
        if index + 1 < flow.count {
            index += 1
        } else {
            onboardingState.markCompleted()
        }
    }

    private func back() {
        guard index > 0 else { return }
        index -= 1
    }

    private func rebuildFlow() {
        flow = OnboardingStep.baseFlow(deliveryStyle: appState.notificationDeliveryStyle)
        if onboardingState.needsSystemPermissions {
            flow.append(.systemPermissions)
        }
        if onboardingState.needsMenuBarTip {
            flow.append(.menuBarTip)
        }
        if flow.isEmpty {
            flow = [.welcome]
        }
        index = 0
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case notificationStyle
    case notificationPermission
    case media
    case systemPermissions
    case menuBarTip

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Pomodoro"
        case .notificationStyle:
            return "Notification Style"
        case .notificationPermission:
            return "Enable Notifications"
        case .media:
            return "Audio & Music"
        case .systemPermissions:
            return "Calendar & Reminders"
        case .menuBarTip:
            return "Menu Bar Tip"
        }
    }

    static func baseFlow(deliveryStyle: NotificationDeliveryStyle) -> [OnboardingStep] {
        if deliveryStyle == .system {
            return [.welcome, .notificationStyle, .notificationPermission, .media]
        } else {
            return [.welcome, .notificationStyle, .media]
        }
    }
}
