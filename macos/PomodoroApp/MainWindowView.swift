import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Pomodoro")
                .font(.largeTitle)
            Text("Ready to focus.")
                .foregroundStyle(.secondary)
            MediaControlBar()
            DebugStateView()
        }
        .frame(minWidth: 480, minHeight: 320)
        .padding(32)
        .task {
            // Connect to system media after first render to prevent blocking main thread
            #if DEBUG
            print("[MainWindowView] First render complete, connecting to system media")
            #endif
            appState.systemMedia.connect()
        }
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AppState())
}
