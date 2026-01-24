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
            
            Text("Grant permissions to enable full app functionality. All buttons open System Settings.")
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
            
            Text("Note: Tasks work without Reminders access. Reminders sync is optional.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
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
                .frame(width: 32)
            
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
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(isAuthorized ? .green : .blue)
            .disabled(isAuthorized)
        }
    }
}

#Preview {
    SettingsPermissionsView(permissionsManager: .shared)
        .frame(width: 600, height: 400)
}
