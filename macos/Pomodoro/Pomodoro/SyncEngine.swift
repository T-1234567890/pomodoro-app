import Foundation
import EventKit

/// Centralized sync engine for tasks, reminders, and calendar events.
/// - External ID rules:
///   - Tasks use pomodoroapp://task/<UUID>
///   - Calendar events use pomodoroapp://event/<UUID>
///   - External IDs are stored inside `notes` and are the sole matching key.
/// - Conflict resolution: lastModified wins (remote vs. local).
@MainActor
final class SyncEngine {
    private let eventStore: EKEventStore
    private let permissionsManager: PermissionsManager
    private weak var todoStore: TodoStore?
    
    init(permissionsManager: PermissionsManager, todoStore: TodoStore? = nil, eventStore: EKEventStore = EKEventStore()) {
        self.permissionsManager = permissionsManager
        self.todoStore = todoStore
        self.eventStore = eventStore
    }
    
    func attachTodoStore(_ store: TodoStore) {
        todoStore = store
    }
    
    func syncAll() async throws {
        try await syncTasksWithReminders()
        try await syncCalendarEvents()
    }
    
    func syncTasksWithReminders() async throws {
        let start = Date()
        var stats = SyncStats()
        print("[SyncEngine] Reminders sync start at \(start)")
        
        try await ensureRemindersAccess()
        guard let store = todoStore else { return }
        
        let reminders = await fetchAllReminders()
        stats.read = reminders.count
        
        var reminderMap: [String: EKReminder] = [:]
        reminders.forEach { reminder in
            if let parsed = ExternalID.parse(from: reminder.notes), parsed.externalId.hasPrefix(ExternalID.taskPrefix) {
                reminderMap[parsed.externalId] = reminder
            } else {
                // External/unknown reminder without Pomodoro externalId:
                // treat as outside task scope; do not import or create tasks.
                stats.skipped += 1
            }
        }
        
        // Remote -> Local reconciliation
        for (externalId, reminder) in reminderMap {
            let remoteModified = reminder.lastModifiedDate ?? reminder.creationDate ?? .distantPast
            let cleanNotes = ExternalID.parse(from: reminder.notes)?.cleanNotes
            
            if var local = store.items.first(where: { $0.externalId == externalId }) {
                if remoteModified > local.lastModified {
                    local.title = reminder.title
                    local.notes = cleanNotes
                    local.isCompleted = reminder.isCompleted
                    if let comps = reminder.dueDateComponents,
                       let date = Calendar.current.date(from: comps) {
                        local.dueDate = date
                    }
                    local.reminderIdentifier = reminder.calendarItemIdentifier
                    local.lastModified = remoteModified
                    store.updateItem(local)
                    print("[SyncEngine][Reminders] remote wins for \(externalId)")
                    stats.written += 1
                } else {
                    print("[SyncEngine][Reminders] local wins for \(externalId)")
                }
            } else if let uuid = uuid(from: externalId, expectedPrefix: ExternalID.taskPrefix) {
                let newTask = TodoItem(
                    id: uuid,
                    externalId: externalId,
                    title: reminder.title,
                    notes: cleanNotes,
                    isCompleted: reminder.isCompleted,
                    dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                    durationMinutes: nil,
                    priority: .none,
                    createdAt: reminder.creationDate ?? Date(),
                    modifiedAt: remoteModified,
                    tags: [],
                    reminderIdentifier: reminder.calendarItemIdentifier,
                    calendarEventIdentifier: nil,
                    syncStatus: .synced
                )
                store.addItem(newTask)
                stats.written += 1
            }
        }
        
        // Local -> Remote creation/update
        for item in store.items {
            var task = item
            if task.externalId.isEmpty {
                task.externalId = ExternalID.taskId(for: task.id)
                store.updateItem(task)
            }
            
            guard task.durationMinutes == nil else { continue } // handled via calendar sync
            guard task.dueDate != nil else { continue } // preserve prior behavior
            
            if let reminder = reminderMap[task.externalId] {
                try updateReminder(reminder, with: task)
                var updated = task
                updated.lastModified = Date()
                store.updateItem(updated)
                print("[SyncEngine][Reminders] pushed local to remote for \(task.externalId)")
                stats.written += 1
            } else {
                let reminderId = try createReminder(from: task)
                var updated = task
                updated.reminderIdentifier = reminderId
                updated.lastModified = Date()
                store.updateItem(updated)
                print("[SyncEngine][Reminders] created remote for \(task.externalId)")
                stats.written += 1
            }
        }
        
        let duration = Date().timeIntervalSince(start)
        print("[SyncEngine] Reminders sync end. read: \(stats.read) written: \(stats.written) skipped: \(stats.skipped) duration: \(String(format: "%.2f", duration))s")
    }
    
    func syncCalendarEvents() async throws {
        let start = Date()
        var stats = SyncStats()
        print("[SyncEngine] Calendar sync start at \(start)")
        
        try await ensureCalendarAccess()
        guard let store = todoStore else { return }
        
        let events = fetchUpcomingEvents()
        stats.read = events.count
        
        var eventMap: [String: EKEvent] = [:]
        events.forEach { event in
            if let parsed = ExternalID.parse(from: event.notes),
               (parsed.externalId.hasPrefix(ExternalID.eventPrefix) || parsed.externalId.hasPrefix(ExternalID.taskPrefix)) {
                eventMap[parsed.externalId] = event
            } else {
                // Respect user control: do not import Calendar events that are not Pomodoro-managed.
                stats.skipped += 1
            }
        }
        
        for item in store.items {
            guard item.syncToCalendar else { continue }
            guard item.dueDate != nil else { continue }
            
            let externalId = item.externalId
            let legacyExternalId = ExternalID.eventId(for: item.id)
            if let existing = eventMap[externalId] ?? eventMap[legacyExternalId] {
                let remoteModified = existing.lastModifiedDate ?? existing.creationDate ?? .distantPast
                if remoteModified > item.lastModified {
                    var updated = item
                    updated.title = existing.title
                    updated.notes = ExternalID.parse(from: existing.notes)?.cleanNotes
                    updated.dueDate = existing.startDate
                    updated.calendarEventIdentifier = existing.eventIdentifier
                    updated.linkedCalendarEventId = existing.eventIdentifier
                    updated.lastModified = remoteModified
                    store.updateItem(updated)
                    print("[SyncEngine][Calendar] remote wins for \(externalId)")
                } else {
                    try updateEvent(existing, with: item, externalId: externalId)
                    var updated = item
                    updated.linkedCalendarEventId = existing.eventIdentifier
                    store.updateItem(updated)
                    print("[SyncEngine][Calendar] local wins for \(externalId)")
                }
                stats.written += 1
            } else {
                let eventId = try createEvent(from: item, externalId: externalId)
                var updated = item
                updated.calendarEventIdentifier = eventId
                updated.linkedCalendarEventId = eventId
                updated.lastModified = Date()
                store.updateItem(updated)
                print("[SyncEngine][Calendar] created remote for \(externalId)")
                stats.written += 1
            }
        }
        
        let duration = Date().timeIntervalSince(start)
        print("[SyncEngine] Calendar sync end. read: \(stats.read) written: \(stats.written) skipped: \(stats.skipped) duration: \(String(format: "%.2f", duration))s")
    }
    
    func deleteReminder(for item: TodoItem) async throws {
        guard let reminderIdentifier = item.reminderIdentifier else { return }
        try await ensureRemindersAccess()
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else { return }
        try eventStore.remove(reminder, commit: true)
    }
    
    // MARK: - Permissions
    
    private func ensureRemindersAccess() async throws {
        if permissionsManager.isRemindersAuthorized { return }
        await permissionsManager.requestRemindersPermission()
        if !permissionsManager.isRemindersAuthorized {
            throw SyncError.notAuthorized
        }
    }
    
    private func ensureCalendarAccess() async throws {
        if permissionsManager.isCalendarAuthorized { return }
        await permissionsManager.requestCalendarPermission()
        if !permissionsManager.isCalendarAuthorized {
            throw SyncError.notAuthorized
        }
    }
    
    // MARK: - Reminders Helpers
    
    private func fetchAllReminders() async -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: nil)
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
    
    private func createReminder(from item: TodoItem) throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = item.title
        reminder.notes = combinedNotes(from: item.notes, tags: item.tags, externalId: item.externalId)
        reminder.isCompleted = item.isCompleted
        reminder.dueDateComponents = item.dueDate.flatMap { Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        reminder.priority = reminderPriority(from: item.priority)
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }
    
    private func updateReminder(_ reminder: EKReminder, with item: TodoItem) throws {
        reminder.title = item.title
        reminder.notes = combinedNotes(from: item.notes, tags: item.tags, externalId: item.externalId)
        reminder.isCompleted = item.isCompleted
        reminder.dueDateComponents = item.dueDate.flatMap { Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        reminder.priority = reminderPriority(from: item.priority)
        try eventStore.save(reminder, commit: true)
    }
    
    private func reminderPriority(from todoPriority: TodoItem.Priority) -> Int {
        switch todoPriority {
        case .none:
            return 0
        case .low:
            return 9
        case .medium:
            return 5
        case .high:
            return 1
        }
    }
    
    // MARK: - Calendar Helpers
    
    private func fetchUpcomingEvents() -> [EKEvent] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        let end = Calendar.current.date(byAdding: .month, value: 12, to: now) ?? now
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    private func createEvent(from item: TodoItem, externalId: String) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = item.title
        event.notes = combinedNotes(from: item.notes, tags: item.tags, externalId: externalId)
        event.startDate = item.dueDate
        if let duration = item.durationMinutes {
            event.endDate = item.dueDate?.addingTimeInterval(Double(duration * 60))
        } else if let start = item.dueDate {
            event.endDate = start.addingTimeInterval(30 * 60)
        }
        event.calendar = eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }
    
    private func updateEvent(_ event: EKEvent, with item: TodoItem, externalId: String) throws {
        event.title = item.title
        event.notes = combinedNotes(from: item.notes, tags: item.tags, externalId: externalId)
        event.startDate = item.dueDate
        if let duration = item.durationMinutes {
            event.endDate = item.dueDate?.addingTimeInterval(Double(duration * 60))
        } else if let start = item.dueDate {
            event.endDate = start.addingTimeInterval(30 * 60)
        }
        try eventStore.save(event, span: .thisEvent, commit: true)
    }
    
    // MARK: - Shared Helpers
    
    private func combinedNotes(from userNotes: String?, tags: [String], externalId: String) -> String {
        var baseNotes: String?
        if let notes = userNotes, !notes.isEmpty {
            baseNotes = notes
        }
        if !tags.isEmpty {
            let tagLine = "Tags: \(tags.joined(separator: ", "))"
            if var existing = baseNotes, !existing.isEmpty {
                existing.append("\n\(tagLine)")
                baseNotes = existing
            } else {
                baseNotes = tagLine
            }
        }
        return ExternalID.upsert(in: baseNotes, externalId: externalId)
    }
    
    private func uuid(from externalId: String, expectedPrefix: String) -> UUID? {
        guard externalId.hasPrefix(expectedPrefix) else { return nil }
        let suffix = externalId.replacingOccurrences(of: expectedPrefix, with: "")
        return UUID(uuidString: suffix)
    }
    
    // MARK: - Types
    
    private struct SyncStats {
        var read = 0
        var written = 0
        var skipped = 0
    }
    
    enum SyncError: LocalizedError {
        case notAuthorized
    }
}
