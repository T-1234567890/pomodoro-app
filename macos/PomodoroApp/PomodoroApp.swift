import AppKit
import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var countdownState = CountdownTimerState()
    @State private var menuBarController: MenuBarController?

    init() {
        #if DEBUG
        print("[PomodoroApp] init started")
        #endif
    }

    var body: some Scene {
        #if DEBUG
        let _ = print("[PomodoroApp] body evaluated - first render beginning")
        #endif
        WindowGroup {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(countdownState)
                .task {
                    if menuBarController == nil {
                        menuBarController = MenuBarController(
                            appState: appState,
                            openMainWindow: focusMainWindow,
                            quit: { NSApplication.shared.terminate(nil) }
                        )
                    }
                }
        }
    }

    private func focusMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
