//
//  ContentView.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainWindowView()
    }
}

#Preview {
    let appState = AppState()
    ContentView()
        .environmentObject(appState)
        .environmentObject(appState.nowPlayingRouter)
        .environmentObject(MusicController(ambientNoiseEngine: appState.ambientNoiseEngine))
}
