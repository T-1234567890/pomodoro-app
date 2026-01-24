import Foundation
import EventKit

/// RemindersSync provides optional sync layer between TodoItems and Apple Reminders.
/// The app functions fully without Reminders access.
@MainActor
final class RemindersSync: ObservableObject {
    private let eventStore = EKEventStore()
    private let permissionsManager: PermissionsManager
    private weak var todoStore: TodoStore?
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: String?
    
    init(permissionsManager: PermissionsManager = .shared) {
        self.permissionsManager = permissionsManager
    }
    
    func setTodoStore(_ store: TodoStore) {
        self.todoStore = store
    }
    
    // MARK: - Sync Operations
    
    /// Check if sync is available
    var isSyncAvailable: Bool {
        permissionsManager.isRemindersAuthorized
    }
    
    /// Sync a TodoItem to Apple Reminders
    func syncToReminders(_ item: TodoItem) async throws {
        guard isSyncAvailable else {
            throw SyncError.notAuthorized
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            if let remindersId = item.remindersIdentifier {
                // Update existing reminder
                try await updateReminder(remindersId, with: item)
            } else {
                // Create new reminder
                let reminderId = try await createReminder(from: item)
                todoStore?.linkToReminder(itemId: item.id, remindersId: reminderId)
            }
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
            throw error
        }
    }
    
    /// Remove sync for a TodoItem (does not delete the Reminder)
    func unsyncFromReminders(_ item: TodoItem) {
        guard item.remindersIdentifier != nil else { return }
        todoStore?.unlinkFromReminder(itemId: item.id)
    }
    
    /// Delete reminder from Apple Reminders
    func deleteReminder(_ item: TodoItem) async throws {
        guard isSyncAvailable,
              let remindersId = item.remindersIdentifier,
              let reminder = eventStore.calendarItem(withIdentifier: remindersId) as? EKReminder else {
            return
        }
        
        try eventStore.remove(reminder, commit: true)
        todoStore?.unlinkFromReminder(itemId: item.id)
    }
    
    // MARK: - Private Helpers
    
    private func createReminder(from item: TodoItem) async throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = item.title
        reminder.notes = item.notes
        reminder.isCompleted = item.isCompleted
        
        if let dueDate = item.dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        }
        
        // Set priority
        reminder.priority = reminderPriority(from: item.priority)
        
        // Use default reminders calendar
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        try eventStore.save(reminder, commit: true)
        
        guard let identifier = reminder.calendarItemIdentifier else {
            throw SyncError.failedToSync
        }
        
        return identifier
    }
    
    private func updateReminder(_ remindersId: String, with item: TodoItem) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: remindersId) as? EKReminder else {
            throw SyncError.reminderNotFound
        }
        
        reminder.title = item.title
        reminder.notes = item.notes
        reminder.isCompleted = item.isCompleted
        
        if let dueDate = item.dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        } else {
            reminder.dueDateComponents = nil
        }
        
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
    
    // MARK: - Error Types
    
    enum SyncError: LocalizedError {
        case notAuthorized
        case failedToSync
        case reminderNotFound
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Reminders access not authorized"
            case .failedToSync:
                return "Failed to sync with Reminders"
            case .reminderNotFound:
                return "Reminder not found"
            }
        }
    }
}
