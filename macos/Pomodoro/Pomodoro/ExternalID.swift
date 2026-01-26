import Foundation

/// Helpers for Pomodoro App external IDs stored in notes.
/// Marker format (single line):
/// [PomodoroAppExternalId] pomodoroapp://task/<UUID>
/// [PomodoroAppExternalId] pomodoroapp://event/<UUID>
enum ExternalID {
    static let markerPrefix = "[PomodoroAppExternalId] "
    static let taskPrefix = "pomodoroapp://task/"
    static let eventPrefix = "pomodoroapp://event/"
    
    struct Parsed {
        let externalId: String
        let cleanNotes: String?
    }
    
    static func taskId(for uuid: UUID) -> String {
        taskPrefix + uuid.uuidString
    }
    
    static func eventId(for uuid: UUID) -> String {
        eventPrefix + uuid.uuidString
    }
    
    static func isValid(_ externalId: String) -> Bool {
        if externalId.hasPrefix(taskPrefix) {
            return UUID(uuidString: String(externalId.dropFirst(taskPrefix.count))) != nil
        }
        if externalId.hasPrefix(eventPrefix) {
            return UUID(uuidString: String(externalId.dropFirst(eventPrefix.count))) != nil
        }
        return false
    }
    
    /// Extract a Pomodoro external ID from notes and return remaining content.
    static func parse(from notes: String?) -> Parsed? {
        guard let notes, !notes.isEmpty else { return nil }
        var lines = notes.split(whereSeparator: \.isNewline).map(String.init)
        var matchedId: String?
        lines.removeAll { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(markerPrefix) {
                let candidate = String(trimmed.dropFirst(markerPrefix.count))
                if isValid(candidate) {
                    matchedId = candidate
                    return true
                }
            }
            return false
        }
        
        guard let externalId = matchedId else { return nil }
        let cleaned = lines.joined(separator: "\n")
        return Parsed(externalId: externalId, cleanNotes: cleaned.isEmpty ? nil : cleaned)
    }
    
    /// Insert or replace the marker line while keeping user notes intact.
    static func upsert(in notes: String?, externalId: String) -> String {
        var lines = notes?.split(whereSeparator: \.isNewline).map(String.init) ?? []
        lines.removeAll { $0.trimmingCharacters(in: .whitespaces).hasPrefix(markerPrefix) }
        lines.insert("\(markerPrefix)\(externalId)", at: 0)
        return lines.joined(separator: "\n")
    }
}
