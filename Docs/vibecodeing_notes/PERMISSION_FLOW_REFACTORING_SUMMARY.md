# Permission Flow Refactoring - Summary

## Overview

This PR refactors the Calendar and Reminders permission request flow for the Pomodoro macOS app to follow Apple's best practices and TCC (Transparency, Consent, and Control) guidelines.

## Problem Statement

The app had buttons labeled "Get Calendar Access" and "Get Reminders Access" that were not working correctly:

- ❌ Clicking buttons either did nothing OR only opened System Settings
- ❌ No system permission dialog appeared
- ❌ In System Settings, app did NOT appear under Reminders
- ❌ No user feedback when permissions were denied
- ❌ Poor visual indicators for permission states

## Solution

Implemented a proper permission request flow that:

1. ✅ **First attempts** to request permission programmatically via `EKEventStore.requestAccess()`
2. ✅ **Shows system dialog** when permission status is `.notDetermined`
3. ✅ **Shows in-app alert** when permission status is `.denied` or `.restricted`
4. ✅ **Provides Settings option** only after user sees the alert
5. ✅ **Updates UI indicators** correctly for all states

## Changes Made

### 1. PermissionsManager.swift

**New Published Properties:**
```swift
@Published var showCalendarDeniedAlert = false
@Published var showRemindersDeniedAlert = false
```

**New Methods:**
- `requestCalendarPermission()` - Proper Calendar permission flow
- `requestRemindersPermission()` - Proper Reminders permission flow
- `requestNotificationPermission()` - Consistent Notification flow

**Deprecated Methods:**
- `registerCalendarIntent()` - Forwards to new method
- `registerRemindersIntent()` - Forwards to new method

**Key Logic:**
```swift
switch status {
case .notDetermined:
    // Request permission → System dialog
    let granted = try await eventStore.requestAccess(to: .event)
    if !granted {
        showCalendarDeniedAlert = true
    }
    
case .denied, .restricted:
    // Already denied → Show alert
    showCalendarDeniedAlert = true
    
case .authorized, .fullAccess:
    // Already authorized → Do nothing
    break
}
```

### 2. SettingsPermissionsView.swift

**Updated UI:**
- Added two `.alert()` modifiers for Calendar and Reminders
- Changed button states based on permission status:
  - Not requested: "Enable" (blue, prominent)
  - Denied/Restricted: "Request Again" (bordered)
  - Authorized: "Authorized" label (green background, not clickable)
- Added visual indicators:
  - Gray icon for not requested
  - Red icon for denied/restricted
  - Green icon for authorized

**Alert Structure:**
```swift
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
```

### 3. CalendarView.swift

**Updated Button:**
- Changed text: "Enable Calendar Access" → "Request Calendar Access"
- Changed instruction: "Tap the button" → "Click the button" (macOS convention)
- Added alert for denied calendar access

**Alert Flow:**
- Same structure as SettingsPermissionsView
- Explains why Calendar access is needed
- Provides Settings option

### 4. TodoListView.swift

**Updated Banner:**
- Changed button to call `requestRemindersPermission()`
- Added alert for denied reminders access
- Banner remains visible when permission is denied (non-blocking)

**Key Difference:**
- Reminders is **optional** - app works fully without it
- Calendar is **required** - blocks Calendar view when unauthorized

### 5. Documentation

**Three New Files:**

1. **PERMISSION_FLOW_TEST_PLAN.md** (8KB)
   - Comprehensive test scenarios
   - Expected results for each state
   - Edge case testing
   - Console output verification
   - Success criteria

2. **PERMISSION_FLOW_IMPLEMENTATION_GUIDE.md** (14KB)
   - Architecture overview
   - Flow diagrams
   - Complete code examples
   - Best practices
   - Common issues and solutions
   - Migration guide

3. **PERMISSION_FLOW_COMPARISON.md** (9KB)
   - Before/after comparison
   - Visual flow diagrams
   - UI state comparison
   - Code comparison
   - UX improvement examples

## Technical Details

### Permission States Handled

| State | Description | Action |
|-------|-------------|--------|
| `.notDetermined` | Never requested | Show system dialog |
| `.denied` | User denied | Show alert |
| `.restricted` | Policy/parental controls | Show alert |
| `.authorized` | Full access granted | Do nothing |
| `.fullAccess` | macOS 14+ full access | Do nothing |
| `.writeOnly` | macOS 14+ write-only | Do nothing |

### Visual Indicators

| State | Icon Color | Status Text | Button/Label |
|-------|-----------|-------------|--------------|
| Not Requested | Gray 🔘 | "Not Requested" | "Enable" button |
| Denied | Red 🔴 | "Denied" | "Request Again" button |
| Restricted | Red 🔴 | "Restricted" | "Request Again" button |
| Authorized | Green 🟢 | "Authorized" | "Authorized" label |

### Alert Messages

**Calendar Alert:**
> Calendar access is required to view your events and schedules. You can enable it in System Settings → Privacy & Security → Calendar.

**Reminders Alert:**
> Reminders access allows you to sync tasks with Apple Reminders. You can enable it in System Settings → Privacy & Security → Reminders.

## Backward Compatibility

- Deprecated methods forward to new methods
- No breaking changes for existing code
- Old button behavior still works (though deprecated)

## Testing Status

### Completed ✅
- Swift syntax validation (all files pass)
- Code review (feedback addressed)
- Security checks (CodeQL - no issues)
- Documentation (comprehensive)

### Requires macOS Device 🖥️
- Manual testing with actual permissions
- System dialog verification
- Alert UI verification
- Settings redirect verification
- State indicator verification

**Note:** Cannot build on Linux. Testing must be done on macOS.

## Requirements

### Xcode Project Configuration

**Info.plist Keys:**
```xml
<key>NSCalendarsUsageDescription</key>
<string>Pomodoro needs access to your calendar to display and create time-based events.</string>

<key>NSRemindersUsageDescription</key>
<string>Pomodoro can optionally sync your tasks with Apple Reminders.</string>
```

**Entitlements:**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.personal-information.calendars</key>
<true/>
<key>com.apple.security.personal-information.reminders</key>
<true/>
```

## Expected User Experience

### Scenario 1: First Time User

1. User opens app and navigates to Calendar
2. Sees "Calendar Unavailable" with explanation
3. Clicks "Request Calendar Access" button
4. **System permission dialog appears** 📋
5. User clicks "OK"
6. Calendar loads and shows events ✅

### Scenario 2: User Previously Denied

1. User navigates to Settings → Permissions
2. Sees Calendar status is "Denied" (red)
3. Clicks "Request Again" button
4. **Alert appears explaining denial** 📋
5. Alert provides "Open Settings" option
6. User clicks "Open Settings"
7. System Settings opens to Privacy pane
8. User enables Calendar access
9. Returns to app - status updates to "Authorized" (green) ✅

### Scenario 3: Optional Feature (Reminders)

1. User using Tasks - app works fine
2. Sees banner: "Reminders Sync Disabled"
3. Clicks "Enable" button
4. System dialog appears
5. User can choose:
   - Grant: Tasks sync to Reminders ✅
   - Deny: App continues working normally (no banner after alert dismissed) ✅

## Benefits

### For Users 👥
- ✅ Clear understanding of permission states
- ✅ Informed choices about privacy
- ✅ Guided through enabling permissions
- ✅ No confusion or unexpected Settings redirects
- ✅ Visual feedback (colors, status text)

### For Developers 💻
- ✅ Follows macOS best practices
- ✅ TCC-compliant implementation
- ✅ Clean, maintainable code
- ✅ Comprehensive documentation
- ✅ Easy to test different states
- ✅ Reusable pattern for other permissions

### For App Store Review 📱
- ✅ Proper permission request flow
- ✅ Clear usage descriptions
- ✅ No policy violations
- ✅ Good user experience
- ✅ Follows Human Interface Guidelines

## Files Modified

```
macos/Pomodoro/Pomodoro/
  ├── PermissionsManager.swift         (refactored)
  ├── SettingsPermissionsView.swift   (updated UI)
  ├── CalendarView.swift               (added alert)
  └── TodoListView.swift               (added alert)

Documentation/
  ├── PERMISSION_FLOW_TEST_PLAN.md           (new)
  ├── PERMISSION_FLOW_IMPLEMENTATION_GUIDE.md (new)
  └── PERMISSION_FLOW_COMPARISON.md          (new)
```

## Commit History

1. `30a57f4` - Refactor permission flow to request programmatically first and show alerts on denial
2. `3c97a12` - Address code review feedback - fix UI text and button styling
3. `5abc7ea` - Add comprehensive test plan and implementation guide documentation
4. (current) - Add comparison documentation and summary

## Next Steps

### For Testing:
1. Build app on macOS device
2. Follow PERMISSION_FLOW_TEST_PLAN.md
3. Verify all scenarios work as expected
4. Test with fresh user account (reset permissions)

### For Deployment:
1. Verify Info.plist has usage descriptions
2. Verify entitlements are enabled
3. Test on multiple macOS versions
4. Submit to App Store Review

## Conclusion

This refactoring brings the permission flow in line with macOS best practices and provides a significantly better user experience. The implementation is well-documented, maintainable, and ready for testing on macOS devices.

**Status:** ✅ Implementation Complete - Ready for Manual Testing

---

**Questions or Issues?**
- See PERMISSION_FLOW_IMPLEMENTATION_GUIDE.md for implementation details
- See PERMISSION_FLOW_TEST_PLAN.md for testing procedures
- See PERMISSION_FLOW_COMPARISON.md for before/after comparison
