//
//  ContentView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var onboardingState: OnboardingState

    var body: some View {
        MainWindowView()
            .sheet(isPresented: $onboardingState.isPresented, onDismiss: {
                onboardingState.markCompleted()
            }) {
                OnboardingFlowView()
            }
    }
}

struct PremiumButton: View {
    let title: String
    let action: () -> Void

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLoginSheet = false
    @State private var pendingAction = false

    var body: some View {
        Button(title) {
            if authViewModel.isLoggedIn {
                action()
            } else {
                pendingAction = true
                showLoginSheet = true
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginSheetView()
                .environmentObject(authViewModel)
        }
        .onChange(of: authViewModel.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn, pendingAction {
                pendingAction = false
                showLoginSheet = false
                action()
            }
        }
    }
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
    ContentView()
        .environmentObject(appState)
        .environmentObject(musicController)
        .environmentObject(audioSourceStore)
        .environmentObject(OnboardingState())
        .environmentObject(AuthViewModel.shared)
}
#endif
