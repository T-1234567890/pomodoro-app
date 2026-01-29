import SwiftUI
import EventKit
import AppKit

/// Calendar view showing time-based events and allowing event creation.
/// Blocked when unauthorized with explanation and enable button.
struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var todoStore: TodoStore
    
    @State private var selectedView: ViewType = .day
    @State private var anchorDate: Date = Date()
    @State private var selectedEventIDs: Set<String> = []
    @State private var lastSelectedEventID: String?
    @State private var batchEventDate: Date = Date()
    @State private var showDeleteEventsConfirmation = false
    @State private var batchEventWarning: String?
    
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

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text("Your time-based events and schedules")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
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
                
                if selectedEventIDs.count > 1 {
                    batchEventActionsBar
                }
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
                WeekCalendarView(
                    days: daysInWeek(from: anchorDate),
                    events: calendarManager.events,
                    tasks: todoStore.items
                )
                .frame(maxWidth: maxWidth, alignment: .leading)
            case .month:
                monthContent(maxWidth: maxWidth)
            }
        }
    }
    
    @ViewBuilder
    private func dayContent(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            daySummary
            dayBlocks
        }
        .frame(maxWidth: maxWidth, alignment: Alignment.leading)
        .padding(Edge.Set.horizontal, 8)
    }
    
    @ViewBuilder
    private func monthContent(maxWidth: CGFloat) -> some View {
        CalendarMonthView(
            date: anchorDate,
            events: calendarManager.events
        )
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
    
    private func daysInWeek(from date: Date) -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: startOfDay) else {
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

    private func formatEventTime(_ event: EKEvent) -> String {
        if event.isAllDay {
            return "All day"
        }
        let start = Self.eventTimeFormatter.string(from: event.startDate)
        let end = Self.eventTimeFormatter.string(from: event.endDate)
        return "\(start) - \(end)"
    }

    // MARK: - Day helpers

    private var daySummary: some View {
        let todayEvents = events(for: anchorDate)
        let todayTasks = tasks(for: anchorDate)
        let totalMinutes = todayEvents.reduce(0) { partial, event in
            partial + max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Today Summary")
                .font(.headline)
            HStack(spacing: 12) {
                summaryPill(title: "Blocks", value: "\(todayEvents.count)")
                summaryPill(title: "Tasks", value: "\(todayTasks.count)")
                summaryPill(title: "Planned mins", value: "\(totalMinutes)")
            }
        }
    }

    private var dayBlocks: some View {
        let todayEvents = events(for: anchorDate)
        let todayTasks = tasks(for: anchorDate)

        return ScrollView {
            if todayEvents.isEmpty && todayTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No blocks today")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !todayEvents.isEmpty {
                        Text("Time Blocks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(todayEvents, id: \.eventIdentifier) { event in
                            blockCard(event, events: todayEvents)
                        }
                    }

                    if !todayTasks.isEmpty {
                        Text("Tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(todayTasks) { task in
                            taskCard(task)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 360, alignment: .top)
    }

    // MARK: - Card builders

    private func blockCard(_ event: EKEvent, events: [EKEvent]) -> some View {
        let isSelected = event.eventIdentifier.map { selectedEventIDs.contains($0) } ?? false
        return VStack(alignment: .leading, spacing: 6) {
            Text(event.title ?? "Untitled")
                .font(.headline)
            Text(formatEventTime(event))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let calendar = event.calendar {
                Text(calendar.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(perform: {
            handleEventSelection(event, allEvents: events)
        })
    }

    private func taskCard(_ item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
                .strikethrough(item.isCompleted)
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let due = item.dueDate {
                let day = Self.shortDayFormatter.string(from: due)
                let suffix = item.hasDueTime ? " • \(Self.eventTimeFormatter.string(from: due))" : ""
                Text(day + suffix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }

    // MARK: - Selection helpers

    private func handleEventSelection(_ event: EKEvent, allEvents: [EKEvent]) {
        guard let id = event.eventIdentifier else { return }
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        let isShift = flags.contains(.shift)
        let isCommand = flags.contains(.command)
        
        if isShift, let anchor = lastSelectedEventID,
           let anchorIndex = allEvents.firstIndex(where: { $0.eventIdentifier == anchor }),
           let targetIndex = allEvents.firstIndex(where: { $0.eventIdentifier == id }) {
            let lower = min(anchorIndex, targetIndex)
            let upper = max(anchorIndex, targetIndex)
            let rangeIDs = allEvents[lower...upper].compactMap { $0.eventIdentifier }
            selectedEventIDs.formUnion(rangeIDs)
            lastSelectedEventID = id
            return
        }
        
        if isCommand {
            if selectedEventIDs.contains(id) {
                selectedEventIDs.remove(id)
            } else {
                selectedEventIDs.insert(id)
                lastSelectedEventID = id
            }
            return
        }
        
        // Default single selection
        selectedEventIDs = [id]
        lastSelectedEventID = id
    }
    
    @ViewBuilder
    private var batchEventActionsBar: some View {
        let editableSelection = selectedEventIDs.compactMap { id in
            calendarManager.events.first(where: { $0.eventIdentifier == id })
        }.filter { $0.calendar.allowsContentModifications }
        let hasReadOnly = selectedEventIDs.count != editableSelection.count
        
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("\(selectedEventIDs.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if hasReadOnly {
                    Text("Some events are read-only (holidays/subscribed). Actions apply only to editable ones.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                DatePicker(
                    "Move to",
                    selection: $batchEventDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                
                Button {
                    Task { await applyEventMove(to: batchEventDate, editable: editableSelection) }
                } label: {
                    Label("Move", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)
                .disabled(editableSelection.isEmpty)
                
                Button(role: .destructive) {
                    showDeleteEventsConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(editableSelection.isEmpty)
            }
            
            if let warning = batchEventWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .alert("Delete \(editableSelection.count) events?", isPresented: $showDeleteEventsConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await applyEventDelete(editable: editableSelection) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Read-only events (holidays/subscribed) will not be deleted.")
        }
    }
    
    private func applyEventMove(to date: Date, editable: [EKEvent]) async {
        guard !editable.isEmpty else { return }
        let ids = editable.compactMap { $0.eventIdentifier }
        do {
            try await calendarManager.moveEvents(with: ids, to: date)
            selectedEventIDs.removeAll()
            lastSelectedEventID = nil
            await loadEvents()
        } catch {
            batchEventWarning = "Could not move all events: \(error.localizedDescription)"
            print("[CalendarView] move events failed: \(error)")
        }
    }
    
    private func applyEventDelete(editable: [EKEvent]) async {
        guard !editable.isEmpty else { return }
        let ids = editable.compactMap { $0.eventIdentifier }
        do {
            try await calendarManager.deleteEvents(with: ids)
            selectedEventIDs.removeAll()
            lastSelectedEventID = nil
            await loadEvents()
        } catch {
            batchEventWarning = "Could not delete all events: \(error.localizedDescription)"
            print("[CalendarView] delete events failed: \(error)")
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Data helpers

    private func events(for day: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return calendarManager.events
            .filter { calendar.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
    }

    private func tasks(for day: Date) -> [TodoItem] {
        let calendar = Calendar.current
        return todoStore.items.filter { item in
            if let due = item.dueDate {
                return calendar.isDate(due, inSameDayAs: day)
            }
            return false
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
