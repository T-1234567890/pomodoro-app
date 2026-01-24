import SwiftUI
import EventKit

/// Calendar view showing time-based events.
/// Blocked when unauthorized with explanation and enable button.
struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var permissionsManager: PermissionsManager
    
    @State private var selectedView: ViewType = .today
    
    private static let eventTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()
    
    enum ViewType {
        case today
        case week
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if permissionsManager.isCalendarAuthorized {
                authorizedContent
            } else {
                unauthorizedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            permissionsManager.refreshCalendarStatus()
            if permissionsManager.isCalendarAuthorized {
                Task {
                    await loadEvents()
                }
            }
        }
    }
    
    private var authorizedContent: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("Calendar")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your time-based events and schedules")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            
            // View selector
            Picker("View", selection: $selectedView) {
                Text("Today").tag(ViewType.today)
                Text("Week").tag(ViewType.week)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .onChange(of: selectedView) { _ in
                Task {
                    await loadEvents()
                }
            }
            
            // Events list
            ScrollView {
                if calendarManager.isLoading {
                    ProgressView("Loading events...")
                        .padding(32)
                } else if calendarManager.events.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No events")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("You have no events in this time period")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(48)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(calendarManager.events, id: \.eventIdentifier) { event in
                            eventRow(event)
                        }
                    }
                    .padding(16)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }
    
    private var unauthorizedContent: some View {
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
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Enable Calendar access in System Settings to use this feature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 400)
            
            Button(action: {
                Task {
                    await permissionsManager.registerCalendarIntent()
                }
            }) {
                Label("Enable Calendar Access", systemImage: "calendar")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }
    
    @ViewBuilder
    private func eventRow(_ event: EKEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(formatEventTime(event))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let calendar = event.calendar {
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text(calendar.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatEventTime(_ event: EKEvent) -> String {
        if event.isAllDay {
            return "All day"
        } else {
            let start = Self.eventTimeFormatter.string(from: event.startDate)
            let end = Self.eventTimeFormatter.string(from: event.endDate)
            return "\(start) - \(end)"
        }
    }
    
    private func loadEvents() async {
        switch selectedView {
        case .today:
            await calendarManager.fetchTodayEvents()
        case .week:
            await calendarManager.fetchWeekEvents()
        }
    }
}

#Preview {
    CalendarView(
        calendarManager: CalendarManager(),
        permissionsManager: .shared
    )
    .frame(width: 700, height: 600)
}
