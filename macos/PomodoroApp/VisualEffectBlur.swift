import AppKit
import SwiftUI

/// A SwiftUI view that provides true macOS wallpaper blur (vibrancy) using NSVisualEffectView.
///
/// Why `.background(.ultraThinMaterial)` failed:
/// - SwiftUI's Material is a compositing layer that doesn't create true vibrancy
/// - It cannot access the desktop wallpaper layer beneath the window
/// - NSVisualEffectView is required for actual wallpaper blur on macOS
///
/// This component wraps NSVisualEffectView to provide:
/// - Real wallpaper blur that shows through to the desktop
/// - Automatic light/dark mode adaptation
/// - Proper vibrancy and blending with window content
struct VisualEffectBlur: NSViewRepresentable {
    /// The visual effect material to use for the blur
    var material: NSVisualEffectView.Material
    
    /// The blending mode determines how content is blended with the blur
    var blendingMode: NSVisualEffectView.BlendingMode
    
    /// Default initializer with sensible defaults for a floating HUD-style window
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        
        // Configure the visual effect view for proper wallpaper blur
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        
        // Ensure the view doesn't interfere with hit testing
        view.wantsLayer = true
        view.autoresizingMask = [.width, .height]
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // Update material and blending mode if they change
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
