import Foundation

/// Primary task data model for the app.
/// Represents both internal todos and synced Apple Reminders.
struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    /// External identifier used for all cross-system sync. Format: pomodoroapp://task/<UUID>
    var externalId: String
    var title: String
    var notes: String?
    var isCompleted: Bool
    var dueDate: Date?
    var durationMinutes: Int?
    var priority: Priority
    var createdAt: Date
    var modifiedAt: Date
    var tags: [String]
    
    /// Optional identifiers for system sync mirrors
    var reminderIdentifier: String?
    var calendarEventIdentifier: String?
    
    enum SyncStatus: String, Codable {
        case local
        case synced
        case conflict
    }
    
    var syncStatus: SyncStatus
    
    enum CodingKeys: String, CodingKey {
        case id, externalId, title, notes, isCompleted, dueDate, durationMinutes, priority, createdAt, modifiedAt, tags, reminderIdentifier, calendarEventIdentifier, syncStatus
    }
    
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
        externalId: String? = nil,
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        durationMinutes: Int? = nil,
        priority: Priority = .none,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = [],
        reminderIdentifier: String? = nil,
        calendarEventIdentifier: String? = nil,
        syncStatus: SyncStatus = .local
    ) {
        self.id = id
        self.externalId = externalId ?? ExternalID.taskId(for: id)
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.durationMinutes = durationMinutes
        self.priority = priority
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.reminderIdentifier = reminderIdentifier
        self.calendarEventIdentifier = calendarEventIdentifier
        self.syncStatus = syncStatus
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let external = try container.decodeIfPresent(String.self, forKey: .externalId) {
            externalId = external
        } else {
            externalId = ExternalID.taskId(for: id)
        }
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .none
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        reminderIdentifier = try container.decodeIfPresent(String.self, forKey: .reminderIdentifier)
        calendarEventIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarEventIdentifier)
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .local
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(externalId, forKey: .externalId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encode(priority, forKey: .priority)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
        try container.encodeIfPresent(reminderIdentifier, forKey: .reminderIdentifier)
        try container.encodeIfPresent(calendarEventIdentifier, forKey: .calendarEventIdentifier)
        try container.encode(syncStatus, forKey: .syncStatus)
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

    /// Convenience alias to align with sync field naming.
    var lastModified: Date {
        get { modifiedAt }
        set { modifiedAt = newValue }
    }
}
