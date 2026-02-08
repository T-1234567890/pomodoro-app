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
    @Published var isAutoSyncEnabled: Bool {
        didSet {
            persistAutoSyncPreference()
            configureAutoSyncBehavior()
        }
    }

    private let autoSyncDefaultsKey = "com.pomodoro.remindersAutoSyncEnabled"
    private var itemChangeCancellable: AnyCancellable?
    private var periodicAutoSyncTask: Task<Void, Never>?
    private var changeTriggeredSyncTask: Task<Void, Never>?
    private var retryBackoffTask: Task<Void, Never>?
    private var autoSyncRetryAttempt = 0

    private let periodicSyncIntervalSeconds: TimeInterval = 300
    private let changeDebounceSeconds: TimeInterval = 1.5
    private let maxBackoffDelaySeconds: TimeInterval = 60
    
    init(permissionsManager: PermissionsManager, syncEngine: SyncEngine? = nil) {
        self.permissionsManager = permissionsManager
        self.syncEngine = syncEngine ?? SyncEngine(permissionsManager: permissionsManager)
        self.isAutoSyncEnabled = UserDefaults.standard.bool(forKey: autoSyncDefaultsKey)
    }

    deinit {
        periodicAutoSyncTask?.cancel()
        changeTriggeredSyncTask?.cancel()
        retryBackoffTask?.cancel()
    }
    
    func setTodoStore(_ store: TodoStore) {
        todoStore = store
        syncEngine.attachTodoStore(store)
        observeLocalItemChanges()
        configureAutoSyncBehavior()
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
            resetAutoSyncBackoff()
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
            resetAutoSyncBackoff()
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

    // MARK: - Auto Sync

    private func observeLocalItemChanges() {
        itemChangeCancellable?.cancel()
        guard let store = todoStore else { return }

        itemChangeCancellable = store.$items
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleChangeTriggeredAutoSync()
            }
    }

    private func configureAutoSyncBehavior() {
        guard isAutoSyncEnabled else {
            stopAutoSync()
            return
        }
        startAutoSyncIfNeeded()
        scheduleChangeTriggeredAutoSync(immediate: true)
    }

    private func startAutoSyncIfNeeded() {
        guard periodicAutoSyncTask == nil else { return }
        periodicAutoSyncTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let nanoseconds = UInt64(periodicSyncIntervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                await self.triggerAutoSync(reason: "periodic")
            }
        }
    }

    private func stopAutoSync() {
        periodicAutoSyncTask?.cancel()
        periodicAutoSyncTask = nil
        changeTriggeredSyncTask?.cancel()
        changeTriggeredSyncTask = nil
        retryBackoffTask?.cancel()
        retryBackoffTask = nil
        autoSyncRetryAttempt = 0
    }

    private func scheduleChangeTriggeredAutoSync(immediate: Bool = false) {
        guard isAutoSyncEnabled else { return }
        changeTriggeredSyncTask?.cancel()
        changeTriggeredSyncTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                let nanoseconds = UInt64(changeDebounceSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard !Task.isCancelled else { return }
            await self.triggerAutoSync(reason: "change")
        }
    }

    private func triggerAutoSync(reason: String) async {
        guard isAutoSyncEnabled else { return }
        guard isSyncAvailable else {
            lastSyncError = "Auto-sync requires Reminders access."
            return
        }
        guard !isSyncing else { return }

        let succeeded = await performAutoSync(mode: reason)
        if succeeded {
            resetAutoSyncBackoff()
        } else {
            scheduleBackoffRetry()
        }
    }

    private func performAutoSync(mode: String) async -> Bool {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await syncEngine.syncTasksWithReminders()
            lastSyncError = nil
            lastSyncDate = Date()
            todoStore?.objectWillChange.send()
            return true
        } catch {
            lastSyncError = "Auto-sync (\(mode)) failed: \(error.localizedDescription)"
            return false
        }
    }

    private func scheduleBackoffRetry() {
        guard isAutoSyncEnabled else { return }
        retryBackoffTask?.cancel()
        autoSyncRetryAttempt += 1
        let delay = min(pow(2.0, Double(max(autoSyncRetryAttempt - 1, 0))), maxBackoffDelaySeconds)
        retryBackoffTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self.triggerAutoSync(reason: "retry")
        }
    }

    private func resetAutoSyncBackoff() {
        autoSyncRetryAttempt = 0
        retryBackoffTask?.cancel()
        retryBackoffTask = nil
    }

    private func persistAutoSyncPreference() {
        UserDefaults.standard.set(isAutoSyncEnabled, forKey: autoSyncDefaultsKey)
    }
}
