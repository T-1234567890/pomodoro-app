//
//  AppDelegate.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import AppKit
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var mainWindow: NSWindow?
    private var appStateConfigured = false
    private var menuBarController: MenuBarController?
    private let mainWindowFrameAutosaveName = "PomodoroMainWindowFrame"

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
    var audioSourceStore: AudioSourceStore? {
        didSet {
            configureControllersIfNeeded()
        }
    }
    var onboardingState: OnboardingState?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.shutdown()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        #if canImport(GoogleSignIn)
        for url in urls {
            if GIDSignIn.sharedInstance.handle(url) {
                return
            }
        }
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = existingWindow() {
            window.applyPomodoroWindowChrome()
            configureWindowPersistence(window)
        }
    }

    func openMainWindow() {
        guard let appState, let musicController, let audioSourceStore else { return }

        if let window = mainWindow ?? existingWindow() {
            focus(window: window)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = true
        window.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(appState)
                .environmentObject(musicController)
                .environmentObject(audioSourceStore)
                .environmentObject(onboardingState ?? OnboardingState())
        )
        window.applyPomodoroWindowChrome()
        configureWindowPersistence(window)
        window.makeKeyAndOrderFront(nil)
        focus(window: window)
        mainWindow = window
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
            quitApp: { [weak self] in
                self?.quitApp()
            }
        )
    }
}
