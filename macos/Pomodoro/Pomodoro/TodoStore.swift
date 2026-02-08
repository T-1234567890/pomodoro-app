import Foundation
import Combine
import SwiftUI

/// TodoStore manages the app's primary task data.
/// This is the source of truth for all tasks, whether synced with Reminders or not.
@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []
    
    private let storageKey = "com.pomodoro.todoItems"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private weak var planningStore: PlanningStore?
    
    init() {
        loadItems()
    }

    func attachPlanningStore(_ store: PlanningStore) {
        planningStore = store
        planningStore?.syncTasks(items)
    }
    
    // MARK: - CRUD Operations
    
    func addItem(_ item: TodoItem) {
        items.append(item)
        saveItems()
        planningStore?.upsertFromTask(item)
    }
    
    func updateItem(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
            planningStore?.upsertFromTask(item)
        }
    }
    
    func deleteItem(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
        planningStore?.removeTaskPlan(for: item.id)
    }
    
    func deleteItems(at offsets: IndexSet) {
        let removedIDs: [UUID] = offsets.map { items[$0].id }
        items.remove(atOffsets: offsets)
        saveItems()
        for id in removedIDs {
            planningStore?.removeTaskPlan(for: id)
        }
    }
    
    func toggleCompletion(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.markComplete(!updatedItem.isCompleted)
            items[index] = updatedItem
            saveItems()
            planningStore?.upsertFromTask(updatedItem)
        }
    }
    
    // MARK: - Filtering
    
    var pendingItems: [TodoItem] {
        items.filter { !$0.isCompleted }
    }
    
    var completedItems: [TodoItem] {
        items.filter { $0.isCompleted }
    }
    
    var itemsWithRemindersSync: [TodoItem] {
        items.filter { $0.reminderIdentifier != nil }
    }
    
    // MARK: - Persistence
    
    private func saveItems() {
        if let encoded = try? encoder.encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? decoder.decode([TodoItem].self, from: data) {
            items = decoded
            planningStore?.syncTasks(items)
        }
    }
    
    // MARK: - Reminders Integration
    
    /// Link a TodoItem to an Apple Reminders identifier
    func linkToReminder(itemId: UUID, remindersId: String) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].reminderIdentifier = remindersId
            items[index].syncStatus = .synced
            saveItems()
        }
    }
    
    /// Unlink a TodoItem from Apple Reminders
    func unlinkFromReminder(itemId: UUID) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].reminderIdentifier = nil
            items[index].syncStatus = .local
            saveItems()
        }
    }
    
    func linkToCalendarEvent(itemId: UUID, eventId: String) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].calendarEventIdentifier = eventId
            items[index].syncStatus = .synced
            saveItems()
            planningStore?.upsertFromTask(items[index])
        }
    }
    
    func unlinkFromCalendarEvent(itemId: UUID) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].calendarEventIdentifier = nil
            items[index].syncStatus = .local
            saveItems()
            planningStore?.upsertFromTask(items[index])
        }
    }
}
