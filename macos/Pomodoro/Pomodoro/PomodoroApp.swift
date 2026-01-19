//
//  PomodoroApp.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState
    @StateObject private var musicController: MusicController

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        _musicController = StateObject(wrappedValue: MusicController(ambientNoiseEngine: appState.ambientNoiseEngine))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.nowPlayingRouter)
                .environmentObject(musicController)
                .task(id: ObjectIdentifier(appState)) {
                    appDelegate.appState = appState
                    appDelegate.musicController = musicController
                }
        }
        .commands {
            CommandMenu("Timer") {
                Button("Start/Pause Pomodoro") {
                    appState.startOrPausePomodoro()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Reset Pomodoro") {
                    appState.resetPomodoro()
                }
                .keyboardShortcut("r", modifiers: [])

                Divider()

                Button("Start Countdown") {
                    appState.startCountdown()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(appState.countdown.state != .idle)
            }
        }
    }
}
