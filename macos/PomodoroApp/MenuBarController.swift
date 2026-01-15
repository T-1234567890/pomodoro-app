import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let openMainWindow: () -> Void
    private let quit: () -> Void

    init(openMainWindow: @escaping () -> Void, quit: @escaping () -> Void) {
        self.openMainWindow = openMainWindow
        self.quit = quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.title = "Pomodoro"
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open Pomodoro",
            action: #selector(openMainWindowAction),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openMainWindowAction() {
        openMainWindow()
    }

    @objc private func quitAction() {
        quit()
    }
}
