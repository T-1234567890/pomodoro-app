import Foundation

/// Lightweight detection of user intent markers in task text.
/// These markers are purely informational and do **not** trigger timers or scheduling.
enum IntentMarkers {
    private static let englishMarkers: [String] = [
        "#pomodoro"
    ]
    
    // Chinese markers are matched as-is (case-sensitive by nature)
    private static let chineseMarkers: [String] = [
        "#专注",
        "#番茄",
        "#番茄钟"
    ]
    
    /// Returns true when text contains any supported intent marker.
    /// - Note: English markers are matched case-insensitively; Chinese markers must match exactly.
    static func containsFocusIntent(in text: String?) -> Bool {
        guard let text = text, !text.isEmpty else { return false }
        let lowercased = text.lowercased()
        if englishMarkers.contains(where: { lowercased.contains($0) }) {
            return true
        }
        return chineseMarkers.contains(where: { text.contains($0) })
    }
}
