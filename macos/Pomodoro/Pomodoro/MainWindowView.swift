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
                Text(appState.pomodoro.state.isOnBreak ? "Break" : "Pomodoro")
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
                Button("Pause") {
                    appState.pomodoro.pause()
                }
                Button("Resume") {
                    appState.pomodoro.resume()
                }
                Button("Reset") {
                    appState.pomodoro.reset()
                }
                Button("Skip Break") {
                    appState.pomodoro.skipBreak()
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
                Button("Pause") {
                    appState.countdown.pause()
                }
                Button("Resume") {
                    appState.countdown.resume()
                }
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

    private func labelForPomodoroState(_ state: PomodoroTimerEngine.State) -> String {
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
}

#Preview {
    MainWindowView()
        .environmentObject(AppState())
}
