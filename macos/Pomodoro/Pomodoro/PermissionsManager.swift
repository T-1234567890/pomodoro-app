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
    
    // Alert state for denied permissions
    @Published var showCalendarDeniedAlert = false
    @Published var showRemindersDeniedAlert = false
    
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
    
    /// Request notification permission - shows system dialog if notDetermined, alert if denied/restricted
    func requestNotificationPermission() async {
        // Check current status
        await refreshNotificationStatus()
        
        switch notificationStatus {
        case .notDetermined:
            // Request permission - this will show the system dialog
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshNotificationStatus()
                
                if !granted {
                    // User denied in the dialog - no additional action needed
                    print("[PermissionsManager] Notification permission denied by user")
                }
            } catch {
                print("[PermissionsManager] Notification request failed: \(error)")
            }
            
        case .denied:
            // Already denied - inform user via alert (handled in UI)
            print("[PermissionsManager] Notification permission already denied")
            // Note: Notifications don't have a dedicated alert flag since they're handled differently in the UI
            // but the pattern is consistent with Calendar/Reminders
            
        case .authorized, .provisional, .ephemeral:
            // Already authorized
            print("[PermissionsManager] Notification permission already authorized")
            
        @unknown default:
            print("[PermissionsManager] Unknown notification status")
        }
    }
    
    /// Request calendar permission - shows system dialog if notDetermined, sets alert flag if denied/restricted
    func requestCalendarPermission() async {
        // Check current status
        refreshCalendarStatus()
        
        switch calendarStatus {
        case .notDetermined:
            // Request permission - this will show the system dialog
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                refreshCalendarStatus()
                
                if !granted {
                    // User denied in the dialog - show alert
                    showCalendarDeniedAlert = true
                    print("[PermissionsManager] Calendar permission denied by user")
                }
            } catch {
                print("[PermissionsManager] Calendar request failed: \(error)")
            }
            
        case .denied, .restricted:
            // Already denied or restricted - show alert
            showCalendarDeniedAlert = true
            print("[PermissionsManager] Calendar permission already denied or restricted")
            
        case .authorized, .fullAccess, .writeOnly:
            // Already authorized
            print("[PermissionsManager] Calendar permission already authorized")
            
        @unknown default:
            print("[PermissionsManager] Unknown calendar status")
        }
    }
    
    /// Request reminders permission - shows system dialog if notDetermined, sets alert flag if denied/restricted
    func requestRemindersPermission() async {
        // Check current status
        refreshRemindersStatus()
        
        switch remindersStatus {
        case .notDetermined:
            // Request permission - this will show the system dialog
            do {
                let granted = try await eventStore.requestAccess(to: .reminder)
                refreshRemindersStatus()
                
                if !granted {
                    // User denied in the dialog - show alert
                    showRemindersDeniedAlert = true
                    print("[PermissionsManager] Reminders permission denied by user")
                }
            } catch {
                print("[PermissionsManager] Reminders request failed: \(error)")
            }
            
        case .denied, .restricted:
            // Already denied or restricted - show alert
            showRemindersDeniedAlert = true
            print("[PermissionsManager] Reminders permission already denied or restricted")
            
        case .authorized, .fullAccess, .writeOnly:
            // Already authorized
            print("[PermissionsManager] Reminders permission already authorized")
            
        @unknown default:
            print("[PermissionsManager] Unknown reminders status")
        }
    }
    
    // MARK: - Legacy Methods (Deprecated)
    
    /// Register notification intent when status is notDetermined
    /// This may show the system prompt once
    @available(*, deprecated, message: "Use requestNotificationPermission() instead")
    func registerNotificationIntent() async {
        await requestNotificationPermission()
    }
    
    /// Register calendar intent when status is notDetermined
    /// This may show the system prompt once
    @available(*, deprecated, message: "Use requestCalendarPermission() instead")
    func registerCalendarIntent() async {
        await requestCalendarPermission()
    }
    
    /// Register reminders intent when status is notDetermined
    /// This may show the system prompt once
    @available(*, deprecated, message: "Use requestRemindersPermission() instead")
    func registerRemindersIntent() async {
        await requestRemindersPermission()
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
