import AppKit
import SwiftUI

final class AppState: ObservableObject {
    private let menuBarController: MenuBarController

    init() {
        menuBarController = MenuBarController(
            openMainWindow: { [weak self] in
                self?.focusMainWindow()
            },
            quit: {
                NSApplication.shared.terminate(nil)
            }
        )
    }

    func focusMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
