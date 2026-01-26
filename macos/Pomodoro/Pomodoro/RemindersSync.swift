import Foundation
import Combine

/// Task-centric sync wrapper that delegates all EventKit work to SyncEngine.
@MainActor
final class RemindersSync: ObservableObject {
    private let permissionsManager: PermissionsManager
    private let syncEngine: SyncEngine
    private weak var todoStore: TodoStore?
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: String?
    @Published var lastSyncDate: Date?
    @Published var isAutoSyncEnabled: Bool = false
    
    init(permissionsManager: PermissionsManager, syncEngine: SyncEngine? = nil) {
        self.permissionsManager = permissionsManager
        self.syncEngine = syncEngine ?? SyncEngine(permissionsManager: permissionsManager)
    }
    
    func setTodoStore(_ store: TodoStore) {
        todoStore = store
        syncEngine.attachTodoStore(store)
    }
    
    // MARK: - Sync Operations
    
    var isSyncAvailable: Bool {
        permissionsManager.isRemindersAuthorized
    }
    
    /// Sync a single task by invoking the unified reminders sync.
    func syncTask(_ item: TodoItem) async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            try await syncEngine.syncTasksWithReminders()
            lastSyncError = nil
            lastSyncDate = Date()
        } catch {
            lastSyncError = error.localizedDescription
            throw error
        }
    }
    
    /// Unified sync for all tasks (delegates to SyncEngine).
    func syncAllTasks() async {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            try await syncEngine.syncAll()
            lastSyncError = nil
            lastSyncDate = Date()
            DispatchQueue.main.async {
                self.todoStore?.objectWillChange.send()
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
    }
    
    /// Remove Reminder link (does not delete remote)
    func unsyncFromReminders(_ item: TodoItem) {
        guard item.reminderIdentifier != nil else { return }
        todoStore?.unlinkFromReminder(itemId: item.id)
    }
    
    /// Delete reminder from Apple Reminders via SyncEngine.
    func deleteReminder(_ item: TodoItem) async throws {
        try await syncEngine.deleteReminder(for: item)
        todoStore?.unlinkFromReminder(itemId: item.id)
    }
}
