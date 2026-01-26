import SwiftUI
import AppKit

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
    @State private var selectedSegment: Segment = .active
    @State private var syncToCalendarField = false
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var lastSelectedTaskID: UUID?
    @State private var batchDueDate: Date = Date()
    @State private var showBatchDeleteConfirmation = false
    @State private var showTaskHint = false
    
    private static let taskHintDefaultsKey = "com.pomodoro.taskHintShown"
    
    private enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case completed = "Completed"
        
        var id: String { rawValue }
    }
    
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
            
            if showTaskHint {
                taskHint
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
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
                
                Picker("", selection: $selectedSegment) {
                    Text("Active").tag(Segment.active)
                    Text("Completed").tag(Segment.completed)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            
            if let last = remindersSync.lastSyncDate {
                HStack {
                    Text("Last sync: \(Self.lastSyncFormatter.string(from: last))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Auto-sync", isOn: $remindersSync.isAutoSyncEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 6)
            }
            
            Divider()
            
            // Batch actions bar (shown only when multi-select is active)
            if selectedTaskIDs.count > 1 {
                batchActionsBar
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
            }
            
            // Tasks list
            ScrollView {
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            todoRow(item)
                                .opacity(selectedSegment == .completed ? 0.9 : 1.0)
                                .allowsHitTesting(selectedSegment == .completed ? false : true)
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
            if !UserDefaults.standard.bool(forKey: Self.taskHintDefaultsKey) {
                showTaskHint = true
            }
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
    
    /// Inline, dismissible hint for first-time task writers.
    private var taskHint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb")
                .font(.title3)
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Write tasks naturally. #pomodoro is optional.")
                    .font(.headline)
                Text("""
Add a # to mark a task as focused work (totally optional):
• Finish biology notes #pomodoro / #专注
• Prepare slides for Monday #番茄 / #番茄钟
This does not start a timer or schedule time—tasks work fine without #.
""")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                showTaskHint = false
                UserDefaults.standard.set(true, forKey: Self.taskHintDefaultsKey)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func todoRow(_ item: TodoItem) -> some View {
        let isSelected = selectedTaskIDs.contains(item.id)
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
                
                if IntentMarkers.containsFocusIntent(in: item.title) || IntentMarkers.containsFocusIntent(in: item.notes) {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Marked for focused work (#pomodoro / #专注 / #番茄 / #番茄钟)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    } else if item.syncToCalendar, (item.linkedCalendarEventId ?? item.calendarEventIdentifier) != nil {
                        Label("In Calendar", systemImage: "calendar.badge.checkmark")
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
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTaskSelection(item)
        }
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
        switch selectedSegment {
        case .active:
            return todoStore.pendingItems
        case .completed:
            return todoStore.completedItems.sorted { $0.modifiedAt > $1.modifiedAt }
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
                
                Toggle("Sync this task to Calendar", isOn: $syncToCalendarField)
                    .toggleStyle(.switch)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.top, 6)
                    .help("Writes this task to Calendar when enabled. Does not auto-schedule or delete events.")
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
        syncToCalendarField = false
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
        syncToCalendarField = item.syncToCalendar
        showingEditor = true
    }
    
    private func resetEditor() {
        editingItem = nil
        titleField = ""
        notesField = ""
        tagsField = ""
        dueDateEnabled = false
        dueDateField = Date()
        syncToCalendarField = false
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
            editing.syncToCalendar = syncToCalendarField
            todoStore.updateItem(editing)
            
            if permissionsManager.isRemindersAuthorized,
               editing.reminderIdentifier != nil {
                Task { try? await remindersSync.syncTask(editing) }
            }
        } else {
            let newItem = TodoItem(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                dueDate: dueDate,
                syncToCalendar: syncToCalendarField
            )
            todoStore.addItem(newItem)
        }
        
        resetEditor()
        showingEditor = false
    }
}

// MARK: - Selection helpers

extension TodoListView {
    fileprivate func handleTaskSelection(_ item: TodoItem) {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        let isShift = flags.contains(.shift)
        let isCommand = flags.contains(.command)
        
        if isShift, let anchor = lastSelectedTaskID,
           let anchorIndex = filteredItems.firstIndex(where: { $0.id == anchor }),
           let targetIndex = filteredItems.firstIndex(where: { $0.id == item.id }) {
            let lower = min(anchorIndex, targetIndex)
            let upper = max(anchorIndex, targetIndex)
            let rangeIDs = filteredItems[lower...upper].map { $0.id }
            selectedTaskIDs.formUnion(rangeIDs)
            lastSelectedTaskID = item.id
            return
        }
        
        if isCommand {
            if selectedTaskIDs.contains(item.id) {
                selectedTaskIDs.remove(item.id)
            } else {
                selectedTaskIDs.insert(item.id)
                lastSelectedTaskID = item.id
            }
            return
        }
        
        // Default single selection
        selectedTaskIDs = [item.id]
        lastSelectedTaskID = item.id
    }
}

// MARK: - Batch actions

extension TodoListView {
    @ViewBuilder
    fileprivate var batchActionsBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedTaskIDs.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            DatePicker(
                "Move to",
                selection: $batchDueDate,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            
            Button {
                applyBatchMove(to: batchDueDate)
            } label: {
                Label("Move", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.bordered)
            
            Button {
                applyBatchClearDate()
            } label: {
                Label("Clear date", systemImage: "calendar.badge.minus")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(role: .destructive) {
                showBatchDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .alert("Delete \(selectedTaskIDs.count) items?", isPresented: $showBatchDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                applyBatchDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all selected tasks. This action cannot be undone.")
        }
    }
    
    /// Move all selected tasks to a specific date (user-invoked, explicit).
    fileprivate func applyBatchMove(to date: Date) {
        let tasks = selectedTasks()
        guard !tasks.isEmpty else { return }
        for var task in tasks {
            task.dueDate = date
            task.modifiedAt = Date()
            todoStore.updateItem(task)
            
            // Propagate to Reminders/Calendar only for managed items; this is user-initiated.
            if permissionsManager.isRemindersAuthorized,
               task.reminderIdentifier != nil {
                Task { try? await remindersSync.syncTask(task) }
            }
        }
        clearTaskSelection()
    }
    
    /// Clear due date on selected tasks.
    fileprivate func applyBatchClearDate() {
        let tasks = selectedTasks()
        guard !tasks.isEmpty else { return }
        for var task in tasks {
            task.dueDate = nil
            task.modifiedAt = Date()
            todoStore.updateItem(task)
            if permissionsManager.isRemindersAuthorized,
               task.reminderIdentifier != nil {
                Task { try? await remindersSync.syncTask(task) }
            }
        }
        clearTaskSelection()
    }
    
    /// Atomic delete for selected tasks.
    fileprivate func applyBatchDelete() {
        let tasks = selectedTasks()
        guard !tasks.isEmpty else { return }
        for task in tasks {
            todoStore.deleteItem(task)
        }
        clearTaskSelection()
    }
    
    private func selectedTasks() -> [TodoItem] {
        todoStore.items.filter { selectedTaskIDs.contains($0.id) }
    }
    
    private func clearTaskSelection() {
        selectedTaskIDs.removeAll()
        lastSelectedTaskID = nil
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
