import Foundation
import EventKit

/// CalendarManager handles EventKit Calendar integration for time-based events.
/// Calendar is a separate feature from Todo/Reminders.
@MainActor
final class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    private let permissionsManager: PermissionsManager
    
    @Published var events: [EKEvent] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    init(permissionsManager: PermissionsManager = .shared) {
        self.permissionsManager = permissionsManager
    }
    
    // MARK: - Access Check
    
    var isAuthorized: Bool {
        permissionsManager.isCalendarAuthorized
    }
    
    // MARK: - Event Fetching
    
    /// Fetch events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async {
        guard isAuthorized else {
            error = "Calendar access not authorized"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        
        let fetchedEvents = eventStore.events(matching: predicate)
        events = fetchedEvents.sorted { $0.startDate < $1.startDate }
        error = nil
    }
    
    /// Fetch events for today
    func fetchTodayEvents() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        await fetchEvents(from: startOfDay, to: endOfDay)
    }
    
    /// Fetch events for current week
    func fetchWeekEvents() async {
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return
        }
        
        await fetchEvents(from: startOfWeek, to: endOfWeek)
    }
    
    // MARK: - Event Creation
    
    /// Create a new calendar event
    func createEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil) async throws {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(event, span: .thisEvent, commit: true)
    }
    
    // MARK: - Error Types
    
    enum CalendarError: LocalizedError {
        case notAuthorized
        case failedToCreate
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Calendar access not authorized"
            case .failedToCreate:
                return "Failed to create calendar event"
            }
        }
    }
}
