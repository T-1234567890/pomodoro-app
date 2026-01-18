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
    private weak var musicWindow: NSWindow?
    private var appStateConfigured = false
    private var menuBarController: MenuBarController?
    private let mainWindowFrameAutosaveName = "PomodoroMainWindowFrame"
    private let musicWindowFrameAutosaveName = "PomodoroMusicWindowFrame"

    var appState: AppState? {
        didSet {
            configureControllersIfNeeded()
        }
    }

    var musicController: MusicController? {
        didSet {
            configureControllersIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.shutdown()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = existingWindow() {
            configureWindowPersistence(window)
        }
    }

    func openMainWindow() {
        guard let appState, let musicController else { return }

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
            rootView: ContentView()
                .environmentObject(appState)
                .environmentObject(appState.localMusicPlayer)
                .environmentObject(musicController)
        )
        configureWindowPersistence(window)
        window.makeKeyAndOrderFront(nil)
        focus(window: window)
        mainWindow = window
    }

    func openMusicPanel() {
        guard let appState else { return }

        if let window = musicWindow {
            focus(window: window)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Music"
        window.isReleasedWhenClosed = true
        window.contentViewController = NSHostingController(
            rootView: MusicPanelView().environmentObject(appState.localMusicPlayer)
        )
        configureWindowPersistence(window, autosaveName: musicWindowFrameAutosaveName)
        window.makeKeyAndOrderFront(nil)
        focus(window: window)
        musicWindow = window
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
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

    private func configureWindowPersistence(_ window: NSWindow) {
        configureWindowPersistence(window, autosaveName: mainWindowFrameAutosaveName)
    }

    private func configureWindowPersistence(_ window: NSWindow, autosaveName: String) {
        window.setFrameAutosaveName(autosaveName)
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
    }

    private func configureControllersIfNeeded() {
        guard !appStateConfigured else { return }
        guard let appState, let musicController else { return }
        appStateConfigured = true
        menuBarController = MenuBarController(
            appState: appState,
            musicController: musicController,
            openMainWindow: { [weak self] in
                self?.openMainWindow()
            },
            openMusicPanel: { [weak self] in
                self?.openMusicPanel()
            },
            quitApp: { [weak self] in
                self?.quitApp()
            }
        )
    }
}
