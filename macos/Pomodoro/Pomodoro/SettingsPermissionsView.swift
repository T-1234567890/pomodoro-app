import SwiftUI
import EventKit

/// Settings view with centralized permission overview.
/// Shows status and enable buttons for Notifications, Calendar, and Reminders.
struct SettingsPermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var showAdvancedAccountTools = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(localizationManager.text("permissions.title"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(localizationManager.text("permissions.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                permissionRow(
                    icon: "bell.fill",
                    title: localizationManager.text("permissions.notifications"),
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
                    title: localizationManager.text("permissions.calendar"),
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
                    title: localizationManager.text("permissions.reminders"),
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
            
            Text(localizationManager.text("permissions.note.reminders_optional"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .onAppear {
            permissionsManager.refreshAllStatuses()
        }
        .alert(localizationManager.text("permissions.calendar.denied_title"), isPresented: $permissionsManager.showCalendarDeniedAlert) {
            Button(localizationManager.text("common.open_settings")) {
                permissionsManager.openSystemSettings()
            }
            Button(localizationManager.text("common.cancel"), role: .cancel) { }
        } message: {
            Text(localizationManager.text("permissions.calendar.denied_message"))
        }
        .alert(localizationManager.text("permissions.reminders.denied_title"), isPresented: $permissionsManager.showRemindersDeniedAlert) {
            Button(localizationManager.text("common.open_settings")) {
                permissionsManager.openSystemSettings()
            }
            Button(localizationManager.text("common.cancel"), role: .cancel) { }
        } message: {
            Text(localizationManager.text("permissions.reminders.denied_message"))
        }

        Divider()

        DisclosureGroup(
            "Account & Cloud (Cloud/AI Features Coming Soon)",
            isExpanded: $showAdvancedAccountTools
        ) {
            CloudSettingsSection()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        }
        .accessibilityLabel("Account & Cloud (Cloud/AI Features Coming Soon)")
        .accessibilityIdentifier("settings.account_cloud_disclosure")
        .font(.subheadline.weight(.medium))
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
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
                Text(localizationManager.text("permissions.authorized"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            } else if isDenied {
                Button(action: action) {
                    Text(localizationManager.text("permissions.request_again"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: action) {
                    Text(localizationManager.text("permissions.enable"))
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
        .environmentObject(AuthViewModel.shared)
}
