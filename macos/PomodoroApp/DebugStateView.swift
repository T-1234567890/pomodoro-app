import SwiftUI

struct DebugStateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var bootTimestamp = Date()

    var body: some View {
        VStack {
            #if DEBUG
            Text("✅ UI Boot Completed")
                .font(.caption)
                .foregroundColor(.green)
            Text("Boot time: \(bootTimestamp, style: .time)")
                .font(.caption2)
                .foregroundColor(.secondary)
            Divider()
            #endif
            Text("currentMode: \(appState.currentMode.displayName)")
            Text("completedWorkSessions: \(appState.completedWorkSessions)")
            Text("workDuration: \(appState.workDuration)")
            Text("breakDuration: \(appState.breakDuration)")
            Text("longBreakDuration: \(appState.longBreakDuration)")
            #if DEBUG
            Divider()
            Text("System Media Active: \(appState.systemMedia.isSessionActive ? "✅" : "❌")")
                .font(.caption)
            if let lastUpdate = appState.systemMedia.lastUpdatedAt {
                Text("Last Update: \(lastUpdate, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            #endif
        }
    }
}

#Preview {
    DebugStateView()
        .environmentObject(AppState())
}
