import Foundation
import Combine

/// TodoStore manages the app's primary task data.
/// This is the source of truth for all tasks, whether synced with Reminders or not.
@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []
    
    private let storageKey = "com.pomodoro.todoItems"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        loadItems()
    }
    
    // MARK: - CRUD Operations
    
    func addItem(_ item: TodoItem) {
        items.append(item)
        saveItems()
    }
    
    func updateItem(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }
    
    func deleteItem(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveItems()
    }
    
    func toggleCompletion(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.markComplete(!updatedItem.isCompleted)
            items[index] = updatedItem
            saveItems()
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
        items.filter { $0.remindersIdentifier != nil }
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
        }
    }
    
    // MARK: - Reminders Integration
    
    /// Link a TodoItem to an Apple Reminders identifier
    func linkToReminder(itemId: UUID, remindersId: String) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].remindersIdentifier = remindersId
            saveItems()
        }
    }
    
    /// Unlink a TodoItem from Apple Reminders
    func unlinkFromReminder(itemId: UUID) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].remindersIdentifier = nil
            saveItems()
        }
    }
}
