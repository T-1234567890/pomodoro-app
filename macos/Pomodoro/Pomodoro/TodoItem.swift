import Foundation
import EventKit

/// Primary task data model for the app.
/// Represents both internal todos and synced Apple Reminders.
struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String?
    var isCompleted: Bool
    var dueDate: Date?
    var priority: Priority
    var createdAt: Date
    var modifiedAt: Date
    
    /// Optional reference to Apple Reminders EKReminder identifier
    /// Only populated when synced with Apple Reminders
    var remindersIdentifier: String?
    
    enum Priority: Int, Codable, CaseIterable {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: Priority = .none,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        remindersIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.remindersIdentifier = remindersIdentifier
    }
    
    mutating func markComplete(_ completed: Bool) {
        isCompleted = completed
        modifiedAt = Date()
    }
    
    mutating func update(title: String? = nil, notes: String? = nil, dueDate: Date? = nil, priority: Priority? = nil) {
        if let title = title { self.title = title }
        if let notes = notes { self.notes = notes }
        if let dueDate = dueDate { self.dueDate = dueDate }
        if let priority = priority { self.priority = priority }
        modifiedAt = Date()
    }
}
