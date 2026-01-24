import Foundation
import EventKit
import UserNotifications

/// Centralized permissions manager for Notifications, Calendar, and Reminders.
/// Provides authorization status checks and system settings opening.
@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    // System Settings URL
    private static let systemSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy"
    
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    @Published var remindersStatus: EKAuthorizationStatus = .notDetermined
    
    private let eventStore = EKEventStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {
        refreshAllStatuses()
    }
    
    // MARK: - Status Refresh
    
    /// Refresh all permission statuses
    func refreshAllStatuses() {
        Task {
            await refreshNotificationStatus()
            refreshCalendarStatus()
            refreshRemindersStatus()
        }
    }
    
    func refreshNotificationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        notificationStatus = settings.authorizationStatus
    }
    
    func refreshCalendarStatus() {
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func refreshRemindersStatus() {
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
    
    // MARK: - Permission Requests
    
    /// Register notification intent when status is notDetermined
    /// This may show the system prompt once
    func registerNotificationIntent() async {
        guard notificationStatus == .notDetermined else {
            openSystemSettings()
            return
        }
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshNotificationStatus()
            
            if !granted {
                openSystemSettings()
            }
        } catch {
            print("[PermissionsManager] Notification request failed: \(error)")
            openSystemSettings()
        }
    }
    
    /// Register calendar intent when status is notDetermined
    /// This may show the system prompt once
    func registerCalendarIntent() async {
        guard calendarStatus == .notDetermined else {
            openSystemSettings()
            return
        }
        
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            refreshCalendarStatus()
            
            if !granted {
                openSystemSettings()
            }
        } catch {
            print("[PermissionsManager] Calendar request failed: \(error)")
            openSystemSettings()
        }
    }
    
    /// Register reminders intent when status is notDetermined
    /// This may show the system prompt once
    func registerRemindersIntent() async {
        guard remindersStatus == .notDetermined else {
            openSystemSettings()
            return
        }
        
        do {
            let granted = try await eventStore.requestAccess(to: .reminder)
            refreshRemindersStatus()
            
            if !granted {
                openSystemSettings()
            }
        } catch {
            print("[PermissionsManager] Reminders request failed: \(error)")
            openSystemSettings()
        }
    }
    
    // MARK: - System Settings
    
    /// Opens macOS System Settings app
    /// This is the primary UX for permission management
    func openSystemSettings() {
        if let url = URL(string: Self.systemSettingsURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Status Helpers
    
    var isNotificationsAuthorized: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional
    }
    
    var isCalendarAuthorized: Bool {
        calendarStatus == .authorized || calendarStatus == .fullAccess
    }
    
    var isRemindersAuthorized: Bool {
        remindersStatus == .authorized || remindersStatus == .fullAccess
    }
    
    var notificationStatusText: String {
        switch notificationStatus {
        case .notDetermined:
            return "Not Requested"
        case .denied:
            return "Denied"
        case .authorized, .provisional:
            return "Authorized"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    var calendarStatusText: String {
        switch calendarStatus {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized, .fullAccess:
            return "Authorized"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }
    
    var remindersStatusText: String {
        switch remindersStatus {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized, .fullAccess:
            return "Authorized"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }
}
