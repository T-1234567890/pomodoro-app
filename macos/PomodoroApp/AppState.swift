import SwiftUI

final class AppState: ObservableObject {
    @Published var currentMode: PomodoroMode = .idle

    init() {}
}
