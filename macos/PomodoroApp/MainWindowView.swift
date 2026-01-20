import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            // Real macOS wallpaper blur using NSVisualEffectView
            // This replaces Rectangle().fill(.ultraThinMaterial) which failed because:
            // - SwiftUI Material is a compositing effect, not true vibrancy
            // - It cannot access the desktop wallpaper layer
            // - NSVisualEffectView with .behindWindow blending is required for wallpaper blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Pomodoro")
                    .font(.largeTitle)
                Text("Ready to focus.")
                    .foregroundStyle(.secondary)
                CountdownTimerView()
                MediaControlBar()
                DebugStateView()
            }
            .frame(minWidth: 480, minHeight: 320)
            .padding(32)
        }
        .background(WindowBackgroundConfigurator())
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
