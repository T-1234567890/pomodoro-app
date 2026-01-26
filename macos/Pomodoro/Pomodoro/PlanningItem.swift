import Foundation

/// Unified planning item for tasks and calendar events.
struct PlanningItem: Identifiable, Codable, Equatable {
    enum SourceType: String, Codable {
        case task
        case reminder
    }
    
    enum Source: String, Codable {
        case local
        case calendar
        case reminders
    }
    
    let id: UUID
    var title: String
    var notes: String?
    var startDate: Date?
    var endDate: Date?
    var isTask: Bool
    var isCalendarEvent: Bool
    var completed: Bool
    var source: Source
    var sourceType: SourceType?
    var sourceID: String?
    var reminderIdentifier: String?
    var calendarEventIdentifier: String?
    var linkedCalendarEventId: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isTask: Bool = true,
        isCalendarEvent: Bool = false,
        completed: Bool = false,
        source: Source = .local,
        sourceType: SourceType? = nil,
        sourceID: String? = nil,
        reminderIdentifier: String? = nil,
        calendarEventIdentifier: String? = nil,
        linkedCalendarEventId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isTask = isTask
        self.isCalendarEvent = isCalendarEvent
        self.completed = completed
        self.source = source
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.reminderIdentifier = reminderIdentifier
        self.calendarEventIdentifier = calendarEventIdentifier
        self.linkedCalendarEventId = linkedCalendarEventId
    }
}
