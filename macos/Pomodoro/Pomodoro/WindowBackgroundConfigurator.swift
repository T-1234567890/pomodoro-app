//
//  WindowBackgroundConfigurator.swift
//  Pomodoro
//
//  Configures the NSWindow to support wallpaper blur while keeping a hidden titlebar with visible controls.
//

import AppKit
import SwiftUI

/// Configures the NSWindow to support wallpaper blur and hidden chrome.
///
/// Responsibilities:
/// - Enables true wallpaper blur by making the window non-opaque with a clear background
/// - Hides the title text and titlebar separator while keeping the traffic lights visible
/// - Keeps the toolbar background invisible so the content can bleed into the titlebar
/// - Preserves window dragging by allowing the full background to act as a drag region
struct WindowBackgroundConfigurator: NSViewRepresentable {
    final class HostingView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyWindowStyling()
        }

        func applyWindowStyling() {
            guard let window else { return }
            window.applyPomodoroWindowChrome()
        }
    }

    func makeNSView(context: Context) -> HostingView {
        HostingView()
    }

    func updateNSView(_ nsView: HostingView, context: Context) {
        nsView.applyWindowStyling()
    }
}

extension NSWindow {
    /// Applies the app's chrome preferences:
    /// - Transparent title bar with hidden title text
    /// - Visible traffic light controls
    /// - Preserves drag gestures on the window background
    /// - Keeps the toolbar area invisible while reserving space for controls
    func applyPomodoroWindowChrome() {
        // Enable wallpaper blur support
        isOpaque = false
        backgroundColor = .clear

        // Hide the textual title while keeping the chrome area
        title = ""
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = true

        installHiddenToolbarIfNeeded()
        showTrafficLights()

        // Ensure vibrancy can pass through
        contentView?.wantsLayer = true
    }

    private func installHiddenToolbarIfNeeded() {
        if toolbar == nil || toolbar?.identifier != .pomodoroHiddenToolbar {
            let toolbar = NSToolbar(identifier: .pomodoroHiddenToolbar)
            toolbar.delegate = HiddenToolbarDelegate.shared
            toolbar.displayMode = .iconOnly
            toolbar.sizeMode = .regular
            toolbar.showsBaselineSeparator = false
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            self.toolbar = toolbar
        }

        toolbar?.isVisible = true
        toolbar?.showsBaselineSeparator = false
        toolbarStyle = .unified
    }

    private func showTrafficLights() {
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        buttons.forEach { type in
            guard let button = standardWindowButton(type) else { return }
            button.isHidden = false
            button.isEnabled = true
            button.superview?.isHidden = false
        }
    }
}

private final class HiddenToolbarDelegate: NSObject, NSToolbarDelegate {
    static let shared = HiddenToolbarDelegate()

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        NSToolbarItem(itemIdentifier: itemIdentifier)
    }
}

private extension NSToolbar.Identifier {
    static let pomodoroHiddenToolbar = NSToolbar.Identifier("PomodoroHiddenToolbar")
}
