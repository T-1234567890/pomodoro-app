# Permission Flow Implementation Guide

## Overview

This document explains the refactored Calendar and Reminders permission flow implementation, demonstrating how to properly request and handle permissions in a macOS SwiftUI app.

## Architecture

### Permission States

```swift
enum EKAuthorizationStatus {
    case notDetermined  // Permission never requested
    case restricted     // Parental controls or policy restriction
    case denied        // User explicitly denied
    case authorized    // Full access granted
    case fullAccess    // macOS 14+ full access (same as authorized)
    case writeOnly     // macOS 14+ write-only access
}
```

### Flow Diagram

```
User clicks "Enable" button
         ↓
Check current status
         ↓
    ┌────┴────┐
    │         │
.notDetermined  .denied/.restricted
    │         │
    ↓         ↓
Request       Show Alert
Permission    "Access Denied"
    │         │
    ↓         ↓
System Dialog  ┌─────────────┐
    │         │Open Settings│
    ↓         │   Cancel    │
User Choice   └─────────────┘
    │
┌───┴───┐
│       │
Allow   Deny
│       │
↓       ↓
✓      Show Alert
```

## Implementation

### 1. PermissionsManager.swift

The centralized manager handles all permission requests and status tracking:

```swift
@MainActor
final class PermissionsManager: ObservableObject {
    // Published status for each permission type
    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    @Published var remindersStatus: EKAuthorizationStatus = .notDetermined
    
    // Alert flags for denied permissions
    @Published var showCalendarDeniedAlert = false
    @Published var showRemindersDeniedAlert = false
    
    private let eventStore = EKEventStore()
    
    /// Request calendar permission - proper flow
    func requestCalendarPermission() async {
        refreshCalendarStatus()
        
        switch calendarStatus {
        case .notDetermined:
            // FIRST: Try to request programmatically
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                refreshCalendarStatus()
                
                if !granted {
                    // User denied in dialog - show alert
                    showCalendarDeniedAlert = true
                }
            } catch {
                print("Calendar request failed: \(error)")
            }
            
        case .denied, .restricted:
            // THEN: If already denied, show alert immediately
            showCalendarDeniedAlert = true
            
        case .authorized, .fullAccess, .writeOnly:
            // Already authorized - do nothing
            break
            
        @unknown default:
            break
        }
    }
    
    /// Open System Settings for manual permission change
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        NSWorkspace.shared.open(url)
    }
}
```

### 2. SwiftUI View Integration

#### Settings Permission Row

```swift
struct SettingsPermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    
    var body: some View {
        VStack {
            permissionRow(
                icon: "calendar",
                title: "Calendar",
                status: permissionsManager.calendarStatusText,
                isAuthorized: permissionsManager.isCalendarAuthorized,
                isDenied: permissionsManager.calendarStatus == .denied ||
                         permissionsManager.calendarStatus == .restricted,
                action: {
                    Task {
                        await permissionsManager.requestCalendarPermission()
                    }
                }
            )
        }
        // Attach alert to view
        .alert("Calendar Access Denied", 
               isPresented: $permissionsManager.showCalendarDeniedAlert) {
            Button("Open Settings") {
                permissionsManager.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Calendar access is required to view your events. " +
                 "You can enable it in System Settings → Privacy & Security → Calendar.")
        }
    }
    
    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        status: String,
        isAuthorized: Bool,
        isDenied: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isAuthorized ? .green : (isDenied ? .red : .secondary))
            
            VStack(alignment: .leading) {
                Text(title)
                Text(status)
                    .foregroundStyle(isAuthorized ? .green : (isDenied ? .red : .secondary))
            }
            
            Spacer()
            
            if isAuthorized {
                // Show styled label (not button)
                Text("Authorized")
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            } else if isDenied {
                // Show "Request Again" button
                Button("Request Again", action: action)
                    .buttonStyle(.bordered)
            } else {
                // Show "Enable" button
                Button("Enable", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

#### Calendar View with Permission Check

```swift
struct CalendarView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    
    var body: some View {
        if permissionsManager.isCalendarAuthorized {
            // Show calendar content
            authorizedContent
        } else {
            // Show permission request UI
            unauthorizedContent
        }
    }
    
    private var unauthorizedContent: some View {
        VStack {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
            
            Text("Calendar Unavailable")
                .font(.title)
            
            Text("Click the button below to request access.")
                .foregroundStyle(.secondary)
            
            Button("Request Calendar Access") {
                Task {
                    await permissionsManager.requestCalendarPermission()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .alert("Calendar Access Denied",
               isPresented: $permissionsManager.showCalendarDeniedAlert) {
            Button("Open Settings") {
                permissionsManager.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Calendar access is required to view your events. " +
                 "You can enable it in System Settings → Privacy & Security → Calendar.")
        }
    }
}
```

#### Optional Reminders Banner

```swift
struct TodoListView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    
    var body: some View {
        VStack {
            // Non-blocking banner for optional feature
            if !permissionsManager.isRemindersAuthorized {
                remindersBanner
            }
            
            // Main content (works without Reminders)
            tasksList
        }
    }
    
    private var remindersBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            Text("Enable Reminders access to sync tasks with Apple Reminders.")
            
            Button("Enable") {
                Task {
                    await permissionsManager.requestRemindersPermission()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .alert("Reminders Access Denied",
               isPresented: $permissionsManager.showRemindersDeniedAlert) {
            Button("Open Settings") {
                permissionsManager.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Reminders access allows you to sync tasks with Apple Reminders. " +
                 "You can enable it in System Settings → Privacy & Security → Reminders.")
        }
    }
}
```

## Best Practices

### 1. Always Check Status First

```swift
// ❌ DON'T: Request without checking
try await eventStore.requestAccess(to: .event)

// ✅ DO: Check current status first
let status = EKEventStore.authorizationStatus(for: .event)
switch status {
case .notDetermined:
    try await eventStore.requestAccess(to: .event)
case .denied:
    showDeniedAlert = true
default:
    break
}
```

### 2. Provide Context in Alerts

```swift
// ❌ DON'T: Generic error message
alert("Access Denied", message: "Permission denied")

// ✅ DO: Explain why and how to fix
alert("Calendar Access Denied") {
    // Actions
} message: {
    Text("Calendar access is required to view your events. " +
         "You can enable it in System Settings → Privacy & Security → Calendar.")
}
```

### 3. Distinguish Required vs Optional Permissions

```swift
// Required permission (Calendar view)
// - Block entire view
// - Prominent "Request Access" button
// - Clear explanation

// Optional permission (Reminders sync)
// - Non-blocking banner
// - App functions without it
// - Easy to dismiss
```

### 4. Visual State Indicators

```swift
func statusColor(for status: EKAuthorizationStatus) -> Color {
    switch status {
    case .notDetermined:
        return .secondary  // Gray - not yet requested
    case .denied, .restricted:
        return .red       // Red - problem needs attention
    case .authorized, .fullAccess:
        return .green     // Green - all good
    case .writeOnly:
        return .orange    // Orange - partial access
    @unknown default:
        return .secondary
    }
}
```

### 5. Async/Await Pattern

```swift
// ✅ Proper async handling
Button("Enable") {
    Task {
        await permissionsManager.requestCalendarPermission()
    }
}

// ❌ DON'T: Block main thread
Button("Enable") {
    // This won't compile with async method
    permissionsManager.requestCalendarPermission()
}
```

## Required Configuration

### 1. Info.plist Usage Descriptions

Add these keys to explain permission usage to users:

```xml
<key>NSCalendarsUsageDescription</key>
<string>Pomodoro needs access to your calendar to display and create time-based events.</string>

<key>NSRemindersUsageDescription</key>
<string>Pomodoro can optionally sync your tasks with Apple Reminders.</string>
```

### 2. App Sandbox Entitlements

Enable these in your Xcode project:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.personal-information.calendars</key>
<true/>
<key>com.apple.security.personal-information.reminders</key>
<true/>
```

## Testing

### Reset Permissions for Testing

Use Terminal to reset permissions:

```bash
# Reset Calendar permissions
tccutil reset Calendar com.yourcompany.Pomodoro

# Reset Reminders permissions
tccutil reset Reminders com.yourcompany.Pomodoro
```

### Verify System Dialog Appears

1. Reset permissions
2. Launch app
3. Click "Enable" button
4. System dialog should appear immediately
5. Dialog shows app name and permission type

### Test Denied State

1. Deny permission in system dialog
2. Verify alert appears with "Open Settings" option
3. Click "Open Settings"
4. Verify System Settings opens to correct pane

## Common Issues

### Issue: Dialog Doesn't Appear

**Cause:** Permission already determined (not `.notDetermined`)

**Solution:** Reset permissions with `tccutil reset`

### Issue: App Not Appearing in System Settings

**Cause:** Missing entitlements or usage description

**Solution:** 
1. Add usage description to Info.plist
2. Enable App Sandbox entitlements
3. Clean build folder and rebuild

### Issue: Alert Shows But Settings Won't Open

**Cause:** Invalid System Settings URL

**Solution:** Use correct URL scheme:
```swift
"x-apple.systempreferences:com.apple.preference.security?Privacy"
```

## Migration from Old Flow

### Old Code (Deprecated)

```swift
// ❌ Old approach - always opens Settings
func registerCalendarIntent() async {
    guard calendarStatus == .notDetermined else {
        openSystemSettings()  // Immediately opens Settings
        return
    }
    
    let granted = try await eventStore.requestAccess(to: .event)
    if !granted {
        openSystemSettings()  // Opens Settings even on denial
    }
}
```

### New Code (Current)

```swift
// ✅ New approach - proper flow
func requestCalendarPermission() async {
    refreshCalendarStatus()
    
    switch calendarStatus {
    case .notDetermined:
        let granted = try await eventStore.requestAccess(to: .event)
        if !granted {
            showCalendarDeniedAlert = true  // Show alert, not Settings
        }
        
    case .denied, .restricted:
        showCalendarDeniedAlert = true  // Show alert first
        
    default:
        break
    }
}
```

### Key Differences

1. **Old:** Immediately opened Settings for denied permissions
2. **New:** Shows in-app alert explaining the situation first

3. **Old:** No distinction between states
4. **New:** Different UI for each state (not requested, denied, authorized)

5. **Old:** No user feedback on denial
6. **New:** Alert explains why permission is needed and how to enable

## Summary

The refactored permission flow follows macOS best practices:

1. ✅ **First:** Attempt programmatic request (`EKEventStore.requestAccess`)
2. ✅ **Then:** Show system dialog for `.notDetermined` state
3. ✅ **Finally:** Show in-app alert for `.denied`/`.restricted` with Settings option

This provides a better user experience by:
- Showing the system dialog when appropriate
- Explaining denials before redirecting to Settings
- Maintaining clear visual state indicators
- Allowing users to make informed decisions

The implementation is backward compatible through deprecated methods and works seamlessly with App Sandbox and TCC permissions on macOS.
