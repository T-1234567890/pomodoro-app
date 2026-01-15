//
//  AppDelegate.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var mainWindow: NSWindow?
    private var appStateConfigured = false

    var appState: AppState? {
        didSet {
            guard !appStateConfigured else { return }
            guard let appState else { return }
            appStateConfigured = true
            appState.openWindowHandler = { [weak self] in
                self?.openMainWindow()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.shutdown()
    }

    func openMainWindow() {
        guard let appState else { return }

        if let window = mainWindow ?? existingWindow() {
            focus(window: window)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pomodoro"
        window.isReleasedWhenClosed = true
        window.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(appState)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        focus(window: window)
        mainWindow = window
    }

    private func existingWindow() -> NSWindow? {
        let window = NSApplication.shared.windows.first { window in
            window.isVisible || window.isMiniaturized
        }
        if let window {
            mainWindow = window
        }
        return window
    }

    private func focus(window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }
}
