import SwiftUI
import EventKit

/// Calendar view showing time-based events and allowing event creation.
/// Blocked when unauthorized with explanation and enable button.
struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var todoStore: TodoStore
    
    @State private var selectedView: ViewType = .day
    @State private var anchorDate: Date = Date()
    
    // New event sheet state
    @State private var showingAddEvent = false
    @State private var newEventTitle: String = ""
    @State private var newEventStart: Date = Date()
    @State private var newEventDurationMinutes: Int = 60
    @State private var newEventNotes: String = ""
    @State private var addEventError: String?
    
    private static let eventTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()
    
    enum ViewType {
        case day
        case week
        case month
        
        var title: String {
            switch self {
            case .day: return "Day"
            case .week: return "Week"
            case .month: return "Month"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if permissionsManager.isCalendarAuthorized {
                authorizedContent
            } else {
                unauthorizedContent
            }
        }
        .frame(minWidth: 520, idealWidth: 680, maxWidth: 900, minHeight: 520, alignment: .top)
        .onAppear {
            permissionsManager.refreshCalendarStatus()
            if permissionsManager.isCalendarAuthorized {
                Task {
                    await loadEvents()
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventSheet(
                title: $newEventTitle,
                startDate: $newEventStart,
                durationMinutes: $newEventDurationMinutes,
                notes: $newEventNotes,
                errorMessage: addEventError,
                onCancel: {
                    showingAddEvent = false
                    addEventError = nil
                },
                onSave: {
                    Task { await saveEvent() }
                }
            )
        }
    }
    
    private var authorizedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            
            // View selector + date anchor + add button
            HStack(spacing: 12) {
                Picker("View", selection: $selectedView) {
                    Text("Day").tag(ViewType.day)
                    Text("Week").tag(ViewType.week)
                    Text("Month").tag(ViewType.month)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                .onChange(of: selectedView) { _, _ in
                    Task { await loadEvents() }
                }
                
                DatePicker(
                    "",
                    selection: $anchorDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .onChange(of: anchorDate) { _, _ in
                    Task { await loadEvents() }
                }
                
                Spacer()
                
                Button {
                    prepareNewEventDefaults()
                    showingAddEvent = true
                } label: {
                    Label("Add Event", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task { await loadEvents() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            
            // Events list constrained to the available detail height
            GeometryReader { proxy in
                ScrollView {
                    eventsContent(maxWidth: proxy.size.width)
                }
                .frame(height: max(proxy.size.height, 280))
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(maxWidth: 860, alignment: .leading)
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
                
                Text("Click the button below to request access.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 400)
            
            Button(action: {
                Task {
                    await permissionsManager.requestCalendarPermission()
                }
            }) {
                Label("Request Calendar Access", systemImage: "calendar")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(48)
        .frame(maxWidth: 520, minHeight: 420, alignment: .center)
        .alert("Calendar Access Denied", isPresented: $permissionsManager.showCalendarDeniedAlert) {
            Button("Open Settings") {
                permissionsManager.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Calendar access is required to view your events. You can enable it in System Settings → Privacy & Security → Calendar.")
        }
    }
    
    @ViewBuilder
    private func eventsContent(maxWidth: CGFloat) -> some View {
        if calendarManager.isLoading {
            ProgressView("Loading events...")
                .padding(32)
                .frame(maxWidth: maxWidth, alignment: .leading)
        } else {
            switch selectedView {
            case .day:
                dayContent(maxWidth: maxWidth)
            case .week:
                weekContent(maxWidth: maxWidth)
            case .month:
                monthContent(maxWidth: maxWidth)
            }
        }
    }
    
    @ViewBuilder
    private func dayContent(maxWidth: CGFloat) -> some View {
        CalendarDayView(
            date: anchorDate,
            events: events(for: anchorDate)
        )
        .frame(maxWidth: maxWidth, alignment: .leading)
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private func weekContent(maxWidth: CGFloat) -> some View {
        let days = daysInWeek(from: anchorDate)
        
        CalendarWeekView(
            days: days,
            events: eventsGroupedByDay(for: days)
        )
        .frame(maxWidth: maxWidth, alignment: .leading)
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private func monthContent(maxWidth: CGFloat) -> some View {
        CalendarMonthView(
            date: anchorDate,
            events: calendarManager.events
        )
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
    
    private func events(for day: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return calendarManager.events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: day)
        }
    }
    
    private func eventsGroupedByDay(for days: [Date]) -> [Date: [EKEvent]] {
        var dict: [Date: [EKEvent]] = [:]
        let calendar = Calendar.current
        for event in calendarManager.events {
            if let match = days.first(where: { calendar.isDate(event.startDate, inSameDayAs: $0) }) {
                dict[match, default: []].append(event)
            }
        }
        return dict
    }
    
    private func daysInWeek(from date: Date) -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
            return days
        }
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek) {
                days.append(day)
            }
        }
        return days
    }
    
    private func loadEvents() async {
        switch selectedView {
        case .day:
            await calendarManager.fetchDayEvents(for: anchorDate)
        case .week:
            await calendarManager.fetchWeekEvents(containing: anchorDate)
        case .month:
            await calendarManager.fetchMonthEvents(containing: anchorDate)
        }
    }
    
    private func prepareNewEventDefaults() {
        newEventTitle = ""
        newEventNotes = ""
        newEventDurationMinutes = 60
        
        // Align start time to the selected date, keeping the current hour.
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let roundedMinute = minute >= 30 ? 30 : 0
        newEventStart = calendar.date(
            bySettingHour: hour,
            minute: roundedMinute,
            second: 0,
            of: anchorDate
        ) ?? anchorDate
    }
    
    private func saveEvent() async {
        let endDate = newEventStart.addingTimeInterval(Double(newEventDurationMinutes * 60))
        do {
            try await calendarManager.createEvent(
                title: newEventTitle.isEmpty ? "New Event" : newEventTitle,
                startDate: newEventStart,
                endDate: endDate,
                notes: newEventNotes.isEmpty ? nil : newEventNotes
            )
            addEventError = nil
            showingAddEvent = false
            await loadEvents()
        } catch {
            addEventError = error.localizedDescription
        }
    }
}

private struct AddEventSheet: View {
    @Binding var title: String
    @Binding var startDate: Date
    @Binding var durationMinutes: Int
    @Binding var notes: String
    
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Event")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                DatePicker("Start", selection: $startDate)
                
                HStack {
                    Text("Duration")
                    Spacer()
                    Stepper("\(durationMinutes) min", value: $durationMinutes, in: 15...480, step: 15)
                }
                
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

#Preview {
    CalendarView(
        calendarManager: CalendarManager(permissionsManager: .shared),
        permissionsManager: .shared,
        todoStore: TodoStore()
    )
    .frame(width: 700, height: 600)
}
