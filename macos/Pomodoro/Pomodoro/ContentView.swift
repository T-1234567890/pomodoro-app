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

#if DEBUG && PREVIEWS_ENABLED
#Preview {
    let appState = AppState()
    ContentView()
        .environmentObject(appState)
        .environmentObject(appState.nowPlayingRouter)
        .environmentObject(MusicController(ambientNoiseEngine: appState.ambientNoiseEngine))
        .environmentObject(OnboardingState())
}
#endif
