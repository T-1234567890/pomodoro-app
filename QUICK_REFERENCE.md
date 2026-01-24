# Quick Reference Card

## For Developers: Essential API & Patterns

### Permission Checking (One-Liner)

```swift
// Check if authorized
let hasCalendar = PermissionsManager.shared.isCalendarAuthorized
let hasReminders = PermissionsManager.shared.isRemindersAuthorized
let hasNotifications = PermissionsManager.shared.isNotificationsAuthorized
```

### Request Permission (Async)

```swift
// In a Button or Task
Button("Enable") {
    Task {
        await PermissionsManager.shared.registerCalendarIntent()
        // Opens System Settings if not .notDetermined
    }
}
```

### Todo Operations

```swift
// Create
let todo = TodoItem(title: "My Task", priority: .high)
todoStore.addItem(todo)

// Update
var updated = todo
updated.title = "Updated"
todoStore.updateItem(updated)

// Complete
todoStore.toggleCompletion(todo)

// Delete
todoStore.deleteItem(todo)
```

### Reminders Sync

```swift
// Check if available
if remindersSync.isSyncAvailable {
    // Sync to Reminders
    try await remindersSync.syncToReminders(todo)
}

// Unsync (keep local, remove link)
remindersSync.unsyncFromReminders(todo)

// Delete from Reminders
try await remindersSync.deleteReminder(todo)
```

### Calendar Events

```swift
// Fetch events
await calendarManager.fetchTodayEvents()
await calendarManager.fetchWeekEvents()

// Access events
for event in calendarManager.events {
    print(event.title)
}
```

### UI Integration

```swift
// In MainWindowView or similar
@StateObject private var permissionsManager = PermissionsManager.shared
@StateObject private var todoStore = TodoStore()
@StateObject private var remindersSync = RemindersSync()
@StateObject private var calendarManager = CalendarManager()

// Connect sync to store
.onAppear {
    remindersSync.setTodoStore(todoStore)
}

// Pass to child views
TodoListView(
    todoStore: todoStore,
    remindersSync: remindersSync,
    permissionsManager: permissionsManager
)
```

### Permission Status UI Pattern

```swift
// Blocking (Calendar)
if permissionsManager.isCalendarAuthorized {
    // Show content
    calendarContent
} else {
    // Show unavailable state
    unauthorizedView
}

// Non-blocking (Tasks with banner)
VStack {
    if !permissionsManager.isRemindersAuthorized {
        // Show banner but don't block
        remindersBanner
    }
    // Always show content
    tasksContent
}
```

## Common Patterns

### 1. Always Check Authorization Before EventKit Calls

```swift
guard permissionsManager.isCalendarAuthorized else {
    // Show unauthorized UI
    return
}
// Safe to use EKEventStore
```

### 2. Refresh Permissions on View Appear

```swift
.onAppear {
    permissionsManager.refreshAllStatuses()
}
```

### 3. Use Weak References to Avoid Retain Cycles

```swift
// In RemindersSync
private weak var todoStore: TodoStore?

func setTodoStore(_ store: TodoStore) {
    self.todoStore = store
}
```

### 4. Cache Expensive Objects

```swift
// DateFormatter
private static let formatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.locale = .autoupdatingCurrent
    return f
}()

// Use it
let dateString = Self.formatter.string(from: date)
```

### 5. Use @MainActor for UI Classes

```swift
@MainActor
final class MyManager: ObservableObject {
    @Published var items: [Item] = []
    // All methods run on main thread
}
```

## File Organization

```
Models:          TodoItem.swift
Storage:         TodoStore.swift
Permissions:     PermissionsManager.swift
Sync:            RemindersSync.swift
Calendar:        CalendarManager.swift
Views:           TodoListView.swift, CalendarView.swift, SettingsPermissionsView.swift
Integration:     MainWindowView.swift
```

## Testing Strategy

### Unit Tests (Future)

```swift
// TodoStore
func testAddItem() { }
func testToggleCompletion() { }

// RemindersSync
func testSyncWhenAuthorized() { }
func testSyncWhenUnauthorized() { }

// PermissionsManager
func testStatusRefresh() { }
```

### Manual Tests

1. ✅ App launches without permissions
2. ✅ Tasks work without permissions
3. ✅ Calendar shows blocked state
4. ✅ Enable buttons open System Settings
5. ✅ After granting permission, UI updates
6. ✅ Tasks sync to Reminders
7. ✅ Calendar shows events

## Debugging Tips

### Permission Issues

```swift
// Check current status
print("Calendar: \(PermissionsManager.shared.calendarStatusText)")
print("Reminders: \(PermissionsManager.shared.remindersStatusText)")

// Force refresh
PermissionsManager.shared.refreshAllStatuses()
```

### Sync Issues

```swift
// Check if sync is available
print("Sync available: \(remindersSync.isSyncAvailable)")

// Check if item is linked
if let id = todo.remindersIdentifier {
    print("Linked to Reminders: \(id)")
}

// Check for sync errors
if let error = remindersSync.lastSyncError {
    print("Sync error: \(error)")
}
```

### Calendar Issues

```swift
// Check authorization
print("Authorized: \(calendarManager.isAuthorized)")

// Check for errors
if let error = calendarManager.error {
    print("Calendar error: \(error)")
}

// Check events
print("Events count: \(calendarManager.events.count)")
```

## Performance Tips

1. **Cache Formatters:** Use static properties
2. **Cache Codables:** Use instance properties
3. **Lazy Loading:** Only load when needed
4. **Weak References:** Prevent retain cycles
5. **@MainActor:** All UI on main thread
6. **Async/Await:** Modern concurrency

## Security Notes

1. **Never store sensitive data in TodoItem**
2. **remindersIdentifier is just a link** (not sensitive)
3. **UserDefaults is local only** (no cloud sync)
4. **Permissions checked before every EventKit call**
5. **System Settings handles actual permissions** (not app)

## Common Mistakes to Avoid

❌ Calling EventKit without checking authorization
❌ Creating DateFormatter in loop
❌ Not handling .notDetermined case
❌ Blocking Tasks view on Reminders permission
❌ Using iOS-specific APIs on macOS

✅ Check authorization first
✅ Cache formatters
✅ Handle all permission states
✅ Non-blocking banner for Reminders
✅ Use macOS-specific APIs (NSWorkspace)

## Quick Migration Guide

### From Old Permission Code

```swift
// Old (inline, scattered)
if EKEventStore.authorizationStatus(for: .event) == .authorized {
    // ...
}

// New (centralized)
if PermissionsManager.shared.isCalendarAuthorized {
    // ...
}
```

### From Direct EventKit

```swift
// Old (direct)
let store = EKEventStore()
let events = store.events(matching: predicate)

// New (managed)
await calendarManager.fetchTodayEvents()
let events = calendarManager.events
```

## API Quick Reference

### PermissionsManager
- `isCalendarAuthorized: Bool`
- `isRemindersAuthorized: Bool`
- `isNotificationsAuthorized: Bool`
- `refreshAllStatuses()`
- `registerCalendarIntent() async`
- `registerRemindersIntent() async`
- `openSystemSettings()`

### TodoStore
- `items: [TodoItem]`
- `addItem(TodoItem)`
- `updateItem(TodoItem)`
- `deleteItem(TodoItem)`
- `toggleCompletion(TodoItem)`
- `pendingItems: [TodoItem]`
- `completedItems: [TodoItem]`

### RemindersSync
- `isSyncAvailable: Bool`
- `syncToReminders(TodoItem) async throws`
- `unsyncFromReminders(TodoItem)`
- `deleteReminder(TodoItem) async throws`

### CalendarManager
- `events: [EKEvent]`
- `isAuthorized: Bool`
- `fetchTodayEvents() async`
- `fetchWeekEvents() async`

## Documentation Links

- **Architecture:** ARCHITECTURE.md
- **Diagram:** ARCHITECTURE_DIAGRAM.md
- **Usage Guide:** USAGE_GUIDE.md
- **Code Examples:** SWIFT_EXAMPLES.md
- **Completion:** COMPLETION_REPORT.md
