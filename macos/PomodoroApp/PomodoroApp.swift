import AppKit
import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var appState = AppState()
    @State private var menuBarController: MenuBarController?

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(appState)
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
