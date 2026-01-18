import SwiftUI

final class AppState: ObservableObject {
    @Published var currentMode: PomodoroMode = .idle
    @Published var completedWorkSessions: Int = 0
    @Published var workDuration: Int = 25 * 60
    @Published var breakDuration: Int = 5 * 60
    @Published var longBreakDuration: Int = 15 * 60
    let mediaPlayer = LocalMediaPlayer()

    init() {}

    func setWorkDuration(minutes: Int) {
        workDuration = minutes * 60
    }
}
