//
//  WindowBackgroundConfigurator.swift
//  Pomodoro
//
//  Configures the NSWindow to support wallpaper blur and vibrancy.
//

import AppKit
import SwiftUI

/// Configures the NSWindow to support wallpaper blur and vibrancy.
///
/// Critical window settings for true wallpaper blur:
/// - isOpaque = false: Allows window to be transparent
/// - backgroundColor = .clear: Removes the default opaque background
/// - titlebarAppearsTransparent: Creates a seamless look
///
/// These settings work in combination with NSVisualEffectView to enable
/// the wallpaper to show through and be blurred by the visual effect view.
struct WindowBackgroundConfigurator: NSViewRepresentable {
    final class HostingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyWindowStyling()
        }

        func applyWindowStyling() {
            guard let window else { return }
            
            // Essential for vibrancy: make the window non-opaque
            window.isOpaque = false
            
            // Essential for vibrancy: clear the default background
            window.backgroundColor = .clear
            
            // Makes the titlebar blend seamlessly with the content
            window.titlebarAppearsTransparent = true
            
            // Ensure the content view allows vibrancy to pass through
            window.contentView?.wantsLayer = true
        }
    }

    func makeNSView(context: Context) -> HostingView {
        HostingView()
    }

    func updateNSView(_ nsView: HostingView, context: Context) {
        nsView.applyWindowStyling()
    }
}
