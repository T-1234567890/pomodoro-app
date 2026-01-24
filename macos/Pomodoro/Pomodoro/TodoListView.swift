import SwiftUI

/// Todo/Tasks view - always accessible with optional Reminders sync.
/// Shows non-blocking banner when Reminders is unauthorized.
struct TodoListView: View {
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var remindersSync: RemindersSync
    @ObservedObject var permissionsManager: PermissionsManager
    
    @State private var showingEditor = false
    @State private var editingItem: TodoItem?
    @State private var titleField = ""
    @State private var notesField = ""
    @State private var tagsField = ""
    @State private var dueDateEnabled = false
    @State private var dueDateField = Date()
    @State private var showCompleted = true
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()
    
    private static let lastSyncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
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
                Button(action: { openEditorForNew() }) {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                if permissionsManager.isRemindersAuthorized {
                    Button {
                        Task { await remindersSync.syncAllTasks() }
                    } label: {
                        if remindersSync.isSyncing {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Syncing…")
                            }
                        } else {
                            Label("Sync All Tasks", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(remindersSync.isSyncing)
                }
                
                Spacer()
                
                Toggle(isOn: $showCompleted) {
                    Text("Show Completed")
                }
                .toggleStyle(.switch)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            
            if let last = remindersSync.lastSyncDate {
                HStack {
                    Text("Last sync: \(Self.lastSyncFormatter.string(from: last))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 6)
            }
            
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
        .sheet(isPresented: $showingEditor) {
            taskEditorSheet
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
                
                Text("Enable Reminders access to sync tasks with Apple Reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Enable") {
                Task {
                    await permissionsManager.requestRemindersPermission()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
        .alert("Reminders Access Denied", isPresented: $permissionsManager.showRemindersDeniedAlert) {
            Button("Open Settings") {
                permissionsManager.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Reminders access allows you to sync tasks with Apple Reminders. You can enable it in System Settings → Privacy & Security → Reminders.")
        }
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
                   item.reminderIdentifier != nil {
                    Task {
                        if let updatedItem = todoStore.items.first(where: { $0.id == item.id }) {
                            try? await remindersSync.syncTask(updatedItem)
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
                
                if !item.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .cornerRadius(4)
                        }
                    }
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
                    
                    if item.reminderIdentifier != nil {
                        Label("Synced", systemImage: "checkmark.icloud")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer()
            
            Menu {
                if permissionsManager.isRemindersAuthorized {
                    if item.reminderIdentifier == nil {
                        Button(action: {
                            Task {
                                try? await remindersSync.syncTask(item)
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
                
                Button {
                    openEditorForEdit(item)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    if item.reminderIdentifier != nil {
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
    
    private var taskEditorSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingItem == nil ? "Add Task" : "Edit Task")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 10) {
                TextField("Title", text: $titleField)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Set due date", isOn: $dueDateEnabled)
                
                if dueDateEnabled {
                    DatePicker(
                        "Due",
                        selection: $dueDateField,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                
                Text("Notes (optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Notes", text: $notesField, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                
                Text("Tags (comma separated, optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g. work, focus", text: $tagsField)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer(minLength: 0)
            
            HStack {
                Button("Cancel") {
                    resetEditor()
                    showingEditor = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(editingItem == nil ? "Add" : "Save") {
                    saveTask()
                }
                .buttonStyle(.borderedProminent)
                .disabled(titleField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
    
    private func openEditorForNew() {
        editingItem = nil
        titleField = ""
        notesField = ""
        tagsField = ""
        dueDateEnabled = false
        dueDateField = Date()
        showingEditor = true
    }
    
    private func openEditorForEdit(_ item: TodoItem) {
        editingItem = item
        titleField = item.title
        notesField = item.notes ?? ""
        tagsField = item.tags.joined(separator: ", ")
        if let due = item.dueDate {
            dueDateEnabled = true
            dueDateField = due
        } else {
            dueDateEnabled = false
            dueDateField = Date()
        }
        showingEditor = true
    }
    
    private func resetEditor() {
        editingItem = nil
        titleField = ""
        notesField = ""
        tagsField = ""
        dueDateEnabled = false
        dueDateField = Date()
    }
    
    private func saveTask() {
        let trimmedTitle = titleField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let dueDate = dueDateEnabled ? dueDateField : nil
        let trimmedNotes = notesField.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = tagsField
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if var editing = editingItem {
            editing.title = trimmedTitle
            editing.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            editing.dueDate = dueDate
            editing.tags = tags
            editing.modifiedAt = Date()
            todoStore.updateItem(editing)
            
            if permissionsManager.isRemindersAuthorized,
               editing.remindersIdentifier != nil {
                Task { try? await remindersSync.syncToReminders(editing) }
            }
        } else {
            let newItem = TodoItem(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                isCompleted: false,
                dueDate: dueDate,
                priority: .none,
                tags: tags
            )
            todoStore.addItem(newItem)
        }
        
        resetEditor()
        showingEditor = false
    }
}

#Preview {
    let store = TodoStore()
    let sync = RemindersSync(permissionsManager: .shared)
    sync.setTodoStore(store)
    
    return TodoListView(
        todoStore: store,
        remindersSync: sync,
        permissionsManager: .shared
    )
    .frame(width: 700, height: 600)
}
