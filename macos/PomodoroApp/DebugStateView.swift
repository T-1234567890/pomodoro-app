import SwiftUI

struct DebugStateView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack {
            Text("currentMode: \(String(describing: appState.currentMode))")
            Text("completedWorkSessions: \(appState.completedWorkSessions)")
            Text("workDuration: \(appState.workDuration)")
            Text("breakDuration: \(appState.breakDuration)")
            Text("longBreakDuration: \(appState.longBreakDuration)")
        }
    }
}

#Preview {
    DebugStateView()
        .environmentObject(AppState())
}
