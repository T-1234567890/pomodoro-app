import AppKit
import SwiftUI

struct WindowBackgroundConfigurator: NSViewRepresentable {
    final class HostingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyWindowStyling()
        }

        func applyWindowStyling() {
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
        }
    }

    func makeNSView(context: Context) -> HostingView {
        HostingView()
    }

    func updateNSView(_ nsView: HostingView, context: Context) {
        nsView.applyWindowStyling()
    }
}
