# Permission Flow Test Plan

## Overview
This document outlines test cases to verify the refactored Calendar and Reminders permission request flow.

## Prerequisites
- macOS Monterey or later
- App Sandbox enabled
- Calendar and Reminders entitlements configured in Xcode project

## Test Scenarios

### 1. Calendar Permission - Not Determined State

**Initial State:**
- Calendar permission status: `.notDetermined`
- No previous permission request

**Steps:**
1. Launch the app
2. Navigate to Settings → Permissions tab
3. Observe Calendar row shows:
   - Status: "Not Requested"
   - Icon: Gray
   - Button: "Enable"
4. Click "Enable" button

**Expected Result:**
- System permission dialog appears
- Dialog shows: "Pomodoro would like to access your calendar"
- Two options: "Don't Allow" and "OK"

**If user clicks "OK":**
- Status updates to "Authorized"
- Icon turns green
- Button changes to "Authorized" label (non-clickable)

**If user clicks "Don't Allow":**
- Alert appears: "Calendar Access Denied"
- Alert message explains how to enable in System Settings
- Two buttons: "Open Settings" and "Cancel"
- Status updates to "Denied"
- Icon turns red
- Button changes to "Request Again"

### 2. Calendar Permission - Already Denied State

**Initial State:**
- Calendar permission status: `.denied`
- User previously denied permission

**Steps:**
1. Launch the app
2. Navigate to Settings → Permissions tab
3. Observe Calendar row shows:
   - Status: "Denied"
   - Icon: Red
   - Button: "Request Again"
4. Click "Request Again" button

**Expected Result:**
- NO system dialog appears
- Alert appears immediately: "Calendar Access Denied"
- Alert message explains how to enable in System Settings
- Two buttons: "Open Settings" and "Cancel"

**If user clicks "Open Settings":**
- System Settings app opens
- Navigates to Privacy & Security section
- User can manually enable Calendar access for the app

**If user clicks "Cancel":**
- Alert dismisses
- Status remains "Denied"

### 3. Calendar Permission - Already Authorized State

**Initial State:**
- Calendar permission status: `.authorized` or `.fullAccess`
- User previously granted permission

**Steps:**
1. Launch the app
2. Navigate to Settings → Permissions tab
3. Observe Calendar row shows:
   - Status: "Authorized"
   - Icon: Green
   - Label: "Authorized" (styled text, not a button)
4. Navigate to Calendar tab

**Expected Result:**
- Calendar events are displayed
- No permission prompt or alert appears
- Events can be viewed and created successfully

### 4. Reminders Permission - Not Determined State

**Initial State:**
- Reminders permission status: `.notDetermined`
- No previous permission request

**Steps:**
1. Launch the app
2. Navigate to Tasks tab
3. Observe banner at top:
   - Warning icon (orange triangle)
   - Text: "Reminders Sync Disabled"
   - Button: "Enable"
4. Click "Enable" button

**Expected Result:**
- System permission dialog appears
- Dialog shows: "Pomodoro would like to access your reminders"
- Two options: "Don't Allow" and "OK"

**If user clicks "OK":**
- Banner disappears
- Tasks can be synced to Apple Reminders
- Sync icon appears on synced tasks

**If user clicks "Don't Allow":**
- Alert appears: "Reminders Access Denied"
- Alert message explains the feature is optional
- Two buttons: "Open Settings" and "Cancel"
- Banner remains visible

### 5. Reminders Permission - Already Denied State

**Initial State:**
- Reminders permission status: `.denied`
- User previously denied permission

**Steps:**
1. Launch the app
2. Navigate to Tasks tab
3. Click "Enable" button in banner

**Expected Result:**
- NO system dialog appears
- Alert appears immediately: "Reminders Access Denied"
- Alert message explains the feature is optional
- Two buttons: "Open Settings" and "Cancel"
- App continues to function normally (Tasks work without Reminders access)

### 6. Calendar View - Unauthorized State

**Initial State:**
- Calendar permission status: `.notDetermined`, `.denied`, or `.restricted`

**Steps:**
1. Launch the app
2. Navigate to Calendar tab

**Expected Result:**
- Empty state view displays:
  - Large calendar icon with exclamation mark
  - Title: "Calendar Unavailable"
  - Description explaining permission is required
  - Button: "Request Calendar Access"
3. Click "Request Calendar Access" button
4. Follow flow based on current permission state (same as Scenario 1 or 2)

### 7. Permission State Indicators

**Test all three permission states across all views:**

| State | Status Text | Icon Color | UI Element |
|-------|-------------|------------|------------|
| Not Requested | "Not Requested" | Gray | "Enable" button |
| Authorized | "Authorized" | Green | "Authorized" label |
| Denied | "Denied" | Red | "Request Again" button |
| Restricted | "Restricted" | Red | "Request Again" button |

### 8. Settings Redirect Verification

**Initial State:**
- Any denied or restricted permission

**Steps:**
1. Trigger denied permission alert
2. Click "Open Settings" button

**Expected Result:**
- System Settings app opens
- Privacy & Security pane is visible
- User can manually enable permissions
- Return to app and refresh status to verify change

### 9. Status Refresh

**Initial State:**
- Permissions in any state

**Steps:**
1. Note current permission status in app
2. Manually change permission in System Settings
3. Return to app
4. Navigate away from and back to Settings/Calendar/Tasks tab

**Expected Result:**
- Permission status updates to reflect System Settings
- UI indicators update correctly
- Functionality enables/disables based on new status

## Console Output Verification

When testing, monitor Console.app for debug messages:

### Expected Log Messages:

**Permission Not Determined → Request:**
```
[PermissionsManager] Requesting calendar/reminders permission...
```

**User Grants:**
```
(No specific log - status refresh occurs)
```

**User Denies:**
```
[PermissionsManager] Calendar/Reminders permission denied by user
```

**Already Denied:**
```
[PermissionsManager] Calendar/Reminders permission already denied or restricted
```

**Already Authorized:**
```
[PermissionsManager] Calendar/Reminders permission already authorized
```

## Edge Cases to Test

### 1. Permission Request During App Suspension
- Request permission, then immediately background the app
- Verify dialog persists and response is handled correctly

### 2. Multiple Rapid Clicks
- Click "Enable" button multiple times rapidly
- Verify only one dialog appears
- Verify no crashes or UI glitches

### 3. Alert During Permission Dialog
- Trigger permission dialog
- While dialog is open, try to trigger another permission request
- Verify graceful handling

### 4. App Restart After Denial
- Deny permission
- Close and relaunch app
- Verify status persists correctly

## Regression Testing

### Verify Existing Functionality Still Works:

1. **Notifications Permission:**
   - Should still request correctly (uses existing flow)
   - Status indicator updates properly

2. **Task Management:**
   - Tasks work completely without Reminders access
   - Creating, editing, completing tasks functions properly
   - Reminders sync only attempted when authorized

3. **Calendar Events:**
   - Can create events when authorized
   - Proper error handling when unauthorized
   - Event display updates correctly

## Success Criteria

All tests pass if:
1. ✅ System permission dialog appears for `.notDetermined` state
2. ✅ No system dialog for `.denied` or `.restricted` states
3. ✅ In-app alerts explain denial with Settings option
4. ✅ Status indicators accurately reflect current state
5. ✅ Settings redirect works correctly
6. ✅ App functionality works within permission constraints
7. ✅ No crashes or UI glitches
8. ✅ Console logs show expected debug messages
9. ✅ Deprecated methods still work (backward compatibility)

## Notes

- The app must have Calendar and Reminders entitlements enabled in Xcode project
- App Sandbox must be enabled
- Test on a clean macOS user account for initial "Not Determined" state testing
- Use `tccutil reset Calendar` and `tccutil reset Reminders` to reset permissions for testing (requires admin privileges)
