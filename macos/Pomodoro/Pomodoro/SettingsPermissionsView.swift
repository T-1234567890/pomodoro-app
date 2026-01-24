import SwiftUI

/// Settings view with centralized permission overview.
/// Shows status and enable buttons for Notifications, Calendar, and Reminders.
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
                            await permissionsManager.requestNotificationPermission()
                        }
                    }
                )
                
                Divider()
                
                permissionRow(
                    icon: "calendar",
                    title: "Calendar",
                    status: permissionsManager.calendarStatusText,
                    isAuthorized: permissionsManager.isCalendarAuthorized,
                    isDenied: permissionsManager.calendarStatus == .denied || permissionsManager.calendarStatus == .restricted,
                    action: {
                        Task {
                            await permissionsManager.requestCalendarPermission()
                        }
                    }
                )
                
                Divider()
                
                permissionRow(
                    icon: "checklist",
                    title: "Reminders",
                    status: permissionsManager.remindersStatusText,
                    isAuthorized: permissionsManager.isRemindersAuthorized,
                    isDenied: permissionsManager.remindersStatus == .denied || permissionsManager.remindersStatus == .restricted,
                    action: {
                        Task {
                            await permissionsManager.requestRemindersPermission()
                        }
                    }
                )
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(12)
            
            Text("Note: Tasks work without Reminders access. Reminders sync is optional.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .onAppear {
            permissionsManager.refreshAllStatuses()
        }
        .alert("Calendar Access Denied", isPresented: $permissionsManager.showCalendarDeniedAlert) {
            Button("Open Settings") {
                permissionsManager.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Calendar access is required to view your events and schedules. You can enable it in System Settings → Privacy & Security → Calendar.")
        }
        .alert("Reminders Access Denied", isPresented: $permissionsManager.showRemindersDeniedAlert) {
            Button("Open Settings") {
                permissionsManager.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Reminders access is optional but allows you to sync tasks with Apple Reminders. You can enable it in System Settings → Privacy & Security → Reminders.")
        }
    }
    
    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        status: String,
        isAuthorized: Bool,
        isDenied: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isAuthorized ? .green : (isDenied ? .red : .secondary))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(status)
                    .font(.caption)
                    .foregroundStyle(isAuthorized ? .green : (isDenied ? .red : .secondary))
            }
            
            Spacer()
            
            if isAuthorized {
                Text("Authorized")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            } else if isDenied {
                Button(action: action) {
                    Text("Request Again")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: action) {
                    Text("Enable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    SettingsPermissionsView(permissionsManager: .shared)
        .frame(width: 600, height: 400)
}
