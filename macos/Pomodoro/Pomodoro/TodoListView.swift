import SwiftUI

/// Todo/Tasks view - always accessible with optional Reminders sync.
/// Shows non-blocking banner when Reminders is unauthorized.
struct TodoListView: View {
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var remindersSync: RemindersSync
    @ObservedObject var permissionsManager: PermissionsManager
    
    @State private var showingAddSheet = false
    @State private var newItemTitle = ""
    @State private var showCompleted = true
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Tasks")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your task list with optional Reminders sync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 16)
            
            // Non-blocking Reminders banner
            if !permissionsManager.isRemindersAuthorized {
                remindersBanner
            }
            
            // Toolbar
            HStack {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Toggle(isOn: $showCompleted) {
                    Text("Show Completed")
                }
                .toggleStyle(.switch)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            
            Divider()
            
            // Tasks list
            ScrollView {
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            todoRow(item)
                        }
                    }
                    .padding(16)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
        .sheet(isPresented: $showingAddSheet) {
            addTaskSheet
        }
        .onAppear {
            permissionsManager.refreshRemindersStatus()
        }
    }
    
    private var remindersBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Reminders Sync Disabled")
                    .font(.headline)
                
                Text("Enable Reminders access in Settings to sync tasks with Apple Reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Enable") {
                Task {
                    await permissionsManager.registerRemindersIntent()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No tasks")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add a task to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
    }
    
    @ViewBuilder
    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                todoStore.toggleCompletion(item)
                
                // Sync to Reminders if authorized and linked
                if permissionsManager.isRemindersAuthorized,
                   item.remindersIdentifier != nil {
                    Task {
                        if let updatedItem = todoStore.items.first(where: { $0.id == item.id }) {
                            try? await remindersSync.syncToReminders(updatedItem)
                        }
                    }
                }
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if item.priority != .none {
                        priorityBadge(item.priority)
                    }
                    
                    if let dueDate = item.dueDate {
                        Label(formatDate(dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if item.remindersIdentifier != nil {
                        Label("Synced", systemImage: "checkmark.icloud")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer()
            
            Menu {
                if permissionsManager.isRemindersAuthorized {
                    if item.remindersIdentifier == nil {
                        Button(action: {
                            Task {
                                try? await remindersSync.syncToReminders(item)
                            }
                        }) {
                            Label("Sync to Reminders", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } else {
                        Button(action: {
                            remindersSync.unsyncFromReminders(item)
                        }) {
                            Label("Unsync from Reminders", systemImage: "xmark.icloud")
                        }
                    }
                    
                    Divider()
                }
                
                Button(role: .destructive, action: {
                    if item.remindersIdentifier != nil {
                        Task {
                            try? await remindersSync.deleteReminder(item)
                        }
                    }
                    todoStore.deleteItem(item)
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func priorityBadge(_ priority: TodoItem.Priority) -> some View {
        Text(priority.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(priority).opacity(0.2))
            .foregroundStyle(priorityColor(priority))
            .cornerRadius(4)
    }
    
    private func priorityColor(_ priority: TodoItem.Priority) -> Color {
        switch priority {
        case .none:
            return .gray
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
    
    private var filteredItems: [TodoItem] {
        if showCompleted {
            return todoStore.items
        } else {
            return todoStore.pendingItems
        }
    }
    
    private var addTaskSheet: some View {
        VStack(spacing: 20) {
            Text("Add Task")
                .font(.title2)
                .fontWeight(.semibold)
            
            TextField("Task title", text: $newItemTitle)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    showingAddSheet = false
                    newItemTitle = ""
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add") {
                    let newItem = TodoItem(title: newItemTitle)
                    todoStore.addItem(newItem)
                    showingAddSheet = false
                    newItemTitle = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newItemTitle.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 200)
    }
}

#Preview {
    let store = TodoStore()
    let sync = RemindersSync()
    sync.setTodoStore(store)
    
    return TodoListView(
        todoStore: store,
        remindersSync: sync,
        permissionsManager: .shared
    )
    .frame(width: 700, height: 600)
}
