# Swift/SwiftUI Code Examples

This document provides code examples for the Calendar, Reminders, and Todo system implementation.

## Permission Status Handling

### Checking Authorization Status

```swift
import EventKit
import UserNotifications

// Check Notifications status
let notificationCenter = UNUserNotificationCenter.current()
let settings = await notificationCenter.notificationSettings()
let isAuthorized = settings.authorizationStatus == .authorized

// Check Calendar status
let calendarStatus = EKEventStore.authorizationStatus(for: .event)
let isCalendarAuthorized = calendarStatus == .authorized || calendarStatus == .fullAccess

// Check Reminders status
let remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
let isRemindersAuthorized = remindersStatus == .authorized || remindersStatus == .fullAccess
```

### Requesting Permissions (When .notDetermined)

```swift
// Notifications - may show system prompt once
if notificationStatus == .notDetermined {
    let granted = try await notificationCenter.requestAuthorization(
        options: [.alert, .sound, .badge]
    )
}

// Calendar - may show system prompt once
if calendarStatus == .notDetermined {
    let eventStore = EKEventStore()
    let granted = try await eventStore.requestAccess(to: .event)
}

// Reminders - may show system prompt once
if remindersStatus == .notDetermined {
    let eventStore = EKEventStore()
    let granted = try await eventStore.requestAccess(to: .reminder)
}
```

### Opening System Settings (Primary UX)

```swift
// Open macOS System Settings
func openSystemSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
        NSWorkspace.shared.open(url)
    }
}

// Specific privacy pane URLs
let notificationsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications"
let calendarURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
let remindersURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
```

## Settings Permission Overview

### Centralized Permission View

```swift
struct SettingsPermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Permissions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Grant permissions to enable full app functionality.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                permissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    status: permissionsManager.notificationStatusText,
                    isAuthorized: permissionsManager.isNotificationsAuthorized,
                    action: {
                        Task {
                            await permissionsManager.registerNotificationIntent()
                        }
                    }
                )
                
                Divider()
                
                permissionRow(
                    icon: "calendar",
                    title: "Calendar",
                    status: permissionsManager.calendarStatusText,
                    isAuthorized: permissionsManager.isCalendarAuthorized,
                    action: {
                        Task {
                            await permissionsManager.registerCalendarIntent()
                        }
                    }
                )
                
                Divider()
                
                permissionRow(
                    icon: "checklist",
                    title: "Reminders",
                    status: permissionsManager.remindersStatusText,
                    isAuthorized: permissionsManager.isRemindersAuthorized,
                    action: {
                        Task {
                            await permissionsManager.registerRemindersIntent()
                        }
                    }
                )
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(12)
        }
        .onAppear {
            permissionsManager.refreshAllStatuses()
        }
    }
    
    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        status: String,
        isAuthorized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isAuthorized ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(status)
                    .font(.caption)
                    .foregroundStyle(isAuthorized ? .green : .secondary)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(isAuthorized ? "Authorized" : "Enable")
            }
            .buttonStyle(.borderedProminent)
            .tint(isAuthorized ? .green : .blue)
            .disabled(isAuthorized)
        }
    }
}
```

## Contextual In-Page Permission Messaging

### Calendar View (Blocking When Unauthorized)

```swift
struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var permissionsManager: PermissionsManager
    
    var body: some View {
        if permissionsManager.isCalendarAuthorized {
            authorizedCalendarContent
        } else {
            unauthorizedCalendarContent
        }
    }
    
    private var unauthorizedCalendarContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                Text("Calendar Unavailable")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Calendar access is required to view your events and schedules.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Enable Calendar access in System Settings to use this feature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 400)
            
            Button(action: {
                Task {
                    await permissionsManager.registerCalendarIntent()
                }
            }) {
                Label("Enable Calendar Access", systemImage: "calendar")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }
    
    private var authorizedCalendarContent: some View {
        // Show calendar events
        ScrollView {
            ForEach(calendarManager.events, id: \.eventIdentifier) { event in
                eventRow(event)
            }
        }
        .task {
            await calendarManager.fetchTodayEvents()
        }
    }
}
```

### Todo View (Non-Blocking Banner)

```swift
struct TodoListView: View {
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var remindersSync: RemindersSync
    @ObservedObject var permissionsManager: PermissionsManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Tasks")
                .font(.largeTitle)
            
            // Non-blocking banner when Reminders unauthorized
            if !permissionsManager.isRemindersAuthorized {
                remindersBanner
            }
            
            // Tasks list (always accessible)
            ScrollView {
                ForEach(todoStore.items) { item in
                    taskRow(item)
                }
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
        .padding(.horizontal)
    }
}
```

## Data Model Relationships

### TodoItem (Primary Model)

```swift
struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var notes: String?
    var isCompleted: Bool
    var dueDate: Date?
    var priority: Priority
    var createdAt: Date
    var modifiedAt: Date
    
    // Optional link to Apple Reminders
    var remindersIdentifier: String?
    
    enum Priority: Int, Codable {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3
    }
}
```

### TodoStore (Local Storage)

```swift
@MainActor
class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []
    
    func addItem(_ item: TodoItem) {
        items.append(item)
        saveToUserDefaults()
    }
    
    func toggleCompletion(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isCompleted.toggle()
            saveToUserDefaults()
        }
    }
}
```

### RemindersSync (Optional Sync Layer)

```swift
@MainActor
class RemindersSync: ObservableObject {
    private let eventStore = EKEventStore()
    
    func syncToReminders(_ item: TodoItem) async throws {
        guard isAuthorized else { throw SyncError.notAuthorized }
        
        if let remindersId = item.remindersIdentifier {
            // Update existing reminder
            try await updateReminder(remindersId, with: item)
        } else {
            // Create new reminder
            let reminderId = try await createReminder(from: item)
            linkToReminder(itemId: item.id, remindersId: reminderId)
        }
    }
    
    private func createReminder(from item: TodoItem) async throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = item.title
        reminder.notes = item.notes
        reminder.isCompleted = item.isCompleted
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier!
    }
}
```

### CalendarManager (Separate Feature)

```swift
@MainActor
class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var events: [EKEvent] = []
    
    func fetchTodayEvents() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        
        await fetchEvents(from: start, to: end)
    }
    
    func fetchEvents(from start: Date, to end: Date) async {
        guard isAuthorized else { return }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: calendars
        )
        
        events = eventStore.events(matching: predicate)
    }
}
```

## Integration Example

### App Setup

```swift
@main
struct PomodoroApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var todoStore = TodoStore()
    @StateObject private var remindersSync = RemindersSync()
    @StateObject private var calendarManager = CalendarManager()
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(permissionsManager)
                .environmentObject(todoStore)
                .environmentObject(remindersSync)
                .environmentObject(calendarManager)
        }
    }
}
```

### Main Window Integration

```swift
struct MainWindowView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var todoStore = TodoStore()
    @StateObject private var remindersSync = RemindersSync()
    @StateObject private var calendarManager = CalendarManager()
    
    @State private var selectedView: ViewType = .tasks
    
    enum ViewType {
        case tasks
        case calendar
        case settings
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Label("Tasks", systemImage: "checklist")
                    .tag(ViewType.tasks)
                Label("Calendar", systemImage: "calendar")
                    .tag(ViewType.calendar)
                Label("Settings", systemImage: "gearshape")
                    .tag(ViewType.settings)
            }
        } detail: {
            switch selectedView {
            case .tasks:
                TodoListView(
                    todoStore: todoStore,
                    remindersSync: remindersSync,
                    permissionsManager: permissionsManager
                )
            case .calendar:
                CalendarView(
                    calendarManager: calendarManager,
                    permissionsManager: permissionsManager
                )
            case .settings:
                SettingsPermissionsView(
                    permissionsManager: permissionsManager
                )
            }
        }
        .onAppear {
            remindersSync.setTodoStore(todoStore)
        }
    }
}
```

## Key Design Patterns

1. **@MainActor for Thread Safety:** All UI-related classes use @MainActor
2. **ObservableObject Pattern:** State management with @Published properties
3. **Async/Await:** Modern Swift concurrency for permission requests
4. **Separation of Concerns:** Clear boundaries between models, sync, and UI
5. **Optional Dependencies:** Todo works without Reminders, Calendar separate
6. **System Settings First:** Primary UX for permission management
7. **Status Indicators:** Clear visual feedback for permission state
8. **Non-Blocking UI:** Tasks always accessible regardless of permissions
