import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: SidebarItem? = .pomodoro
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ZStack {
            // Real macOS wallpaper blur using NSVisualEffectView
            // This replaces Rectangle().fill(.ultraThinMaterial) which failed because:
            // - SwiftUI Material is a compositing effect, not true vibrancy
            // - It cannot access the desktop wallpaper layer
            // - NSVisualEffectView with .behindWindow blending is required for wallpaper blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar
            } detail: {
                detail(for: selectedItem ?? .pomodoro)
            }
            .navigationSplitViewStyle(.balanced)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .onChange(of: columnVisibility) { newValue in
                if newValue != .all {
                    columnVisibility = .all
                }
            }
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

    private var sidebar: some View {
        List(selection: $selectedItem) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item as SidebarItem?)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func detail(for item: SidebarItem) -> some View {
        switch item {
        case .pomodoro:
            pomodoroView
        case .countdown:
            countdownView
        case .audioMusic:
            audioMusicView
        case .summary:
            summaryView
        case .settings:
            settingsView
        }
    }

    private var pomodoroView: some View {
        VStack(spacing: 16) {
            Text("Pomodoro")
                .font(.largeTitle)
            Text("Ready to focus.")
                .foregroundStyle(.secondary)
            CountdownTimerView()
            MediaControlBar()
            DebugStateView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minWidth: 520, minHeight: 360)
        .padding(.top, 64)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    private var countdownView: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Countdown")
                .font(.largeTitle)
            Text("One-off timers for tasks that do not need full Pomodoro cycles.")
                .foregroundStyle(.secondary)
            CountdownTimerView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 64)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    private var audioMusicView: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Audio & Music")
                .font(.largeTitle)
            Text("Control what's playing while you work.")
                .foregroundStyle(.secondary)
            MediaControlBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 64)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    private var summaryView: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Summary")
                .font(.largeTitle)
            Text("Session state and diagnostics.")
                .foregroundStyle(.secondary)
            DebugStateView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 64)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    private var settingsView: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Settings")
                .font(.largeTitle)
            Text("Customize your focus experience.")
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.2))
                .frame(height: 140)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Settings coming soon")
                            .foregroundStyle(.secondary)
                    }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 64)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    private enum SidebarItem: String, CaseIterable, Identifiable {
        case pomodoro
        case countdown
        case audioMusic
        case summary
        case settings

        var id: SidebarItem { self }

        var title: String {
            switch self {
            case .pomodoro:
                return "Pomodoro"
            case .countdown:
                return "Countdown"
            case .audioMusic:
                return "Audio & Music"
            case .summary:
                return "Summary"
            case .settings:
                return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .pomodoro:
                return "timer"
            case .countdown:
                return "hourglass"
            case .audioMusic:
                return "music.note.list"
            case .summary:
                return "chart.bar"
            case .settings:
                return "gearshape"
            }
        }
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AppState())
}
