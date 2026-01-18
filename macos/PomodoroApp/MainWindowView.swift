import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Pomodoro")
                .font(.largeTitle)
            Text("Ready to focus.")
                .foregroundStyle(.secondary)
            Button("Choose Music") {
                appState.localMedia.loadFiles()
            }
            .buttonStyle(.bordered)
            MediaControlBar()
            DebugStateView()
        }
        .frame(minWidth: 480, minHeight: 320)
        .padding(32)
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AppState())
}
