//
//  MainWindowView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState

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
}

#Preview {
    MainWindowView()
        .environmentObject(AppState())
}
