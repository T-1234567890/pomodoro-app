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
    
    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
    
    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()
    
    private static let weekdaySymbols: [String] = {
        let calendar = Calendar.current
        return calendar.shortStandaloneWeekdaySymbols
    }()
    
    private let monthColumns: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 70), spacing: 8), count: 7)
    
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
                weekColumns(maxWidth: maxWidth)
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
        .frame(maxWidth: maxWidth, alignment: .leading)
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private func weekColumns(maxWidth: CGFloat) -> some View {
        let days = daysInWeek(from: anchorDate)
        let grouped = eventsGroupedByDay(for: days)

        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(days, id: \.self) { day in
                    let dayEvents = (grouped[day] ?? []).sorted { $0.startDate < $1.startDate }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day, format: .dateTime.weekday(.abbreviated).day())
                            .font(.headline)
                        if dayEvents.isEmpty {
                            Text("No blocks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(dayEvents, id: \.eventIdentifier) { event in
                                    blockCard(event)
                                }
                            }
                        }
                    }
                    .frame(width: 180, alignment: .topLeading)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: maxWidth, maxHeight: 360, alignment: .topLeading)
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private func monthContent(maxWidth: CGFloat) -> some View {
        let gridDays = monthGridDays(from: anchorDate)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: monthColumns, spacing: 8) {
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    monthCell(for: day)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Day layout (block-based, hides empty hours)

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
                            blockCard(event)
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

    // MARK: - Block cards

    private func blockCard(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
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
                Text(Self.shortDayFormatter.string(from: due))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
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
    
    private func tasks(for day: Date) -> [TodoItem] {
        let calendar = Calendar.current
        return todoStore.items.filter { item in
            if let due = item.dueDate {
                return calendar.isDate(due, inSameDayAs: day)
            }
            return false
        }
    }
    
    private func tasksGroupedByDay(for days: [Date]) -> [Date: [TodoItem]] {
        var dict: [Date: [TodoItem]] = [:]
        let calendar = Calendar.current
        for item in todoStore.items {
            guard let due = item.dueDate else { continue }
            if let match = days.first(where: { calendar.isDate(due, inSameDayAs: $0) }) {
                dict[match, default: []].append(item)
            }
        }
        return dict
    }
    
    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
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
    
    private func daysInMonth(from date: Date) -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return days
        }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    
    private func monthGridDays(from date: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }
    
    @ViewBuilder
    private func emptyState(message: String, maxWidth: CGFloat) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No events")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: maxWidth, alignment: .center)
        .padding(48)
    }
    
    @ViewBuilder
    private func monthCell(for day: Date?) -> some View {
        if let day {
            let calendar = Calendar.current
            let isToday = calendar.isDateInToday(day)
            let dayEvents = events(for: day)
            let dayTasks = tasks(for: day)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.headline)
                        .foregroundStyle(isToday ? .blue : .primary)
                    Spacer()
                    if isToday {
                        Text("Today")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(dayEvents.prefix(3), id: \.eventIdentifier) { event in
                        Text(event.title ?? "Untitled")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    ForEach(dayTasks.prefix(2), id: \.id) { task in
                        Text(task.title)
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(minHeight: 72, alignment: .topLeading)
            .background(isToday ? Color.blue.opacity(0.08) : Color.primary.opacity(0.05))
            .cornerRadius(8)
        } else {
            Rectangle()
                .fill(Color.clear)
                .frame(minHeight: 72)
        }
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
    
    @ViewBuilder
    private func taskRow(_ task: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Task", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Spacer()
                if let due = task.dueDate {
                    Text(Self.eventTimeFormatter.string(from: due))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(task.title)
                .font(.headline)
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !task.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
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

/// Single-day vertical timeline with hour rows.
private struct DayTimelineView: View {
    let date: Date
    let events: [EKEvent]
    let tasks: [TodoItem]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                        Text(hourLabel(hour))
                            .font(.caption)
                            .frame(width: 44, alignment: .trailing)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            let hourEvents = eventsForHour(hour)
                            let hourTasks = tasksForHour(hour)
                            
                            if hourEvents.isEmpty && hourTasks.isEmpty {
                                Text(" ")
                                    .font(.caption2)
                            } else {
                                ForEach(hourEvents, id: \.eventIdentifier) { event in
                                    eventChip(event)
                                }
                                ForEach(hourTasks, id: \.id) { task in
                                    taskChip(task)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    
                    Divider()
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func eventsForHour(_ hour: Int) -> [EKEvent] {
        let calendar = Calendar.current
        return events.filter {
            calendar.component(.hour, from: $0.startDate) == hour
        }
    }
    
    private func tasksForHour(_ hour: Int) -> [TodoItem] {
        let calendar = Calendar.current
        return tasks.filter { item in
            guard let due = item.dueDate else { return false }
            return calendar.component(.hour, from: due) == hour
        }
    }
    
    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func eventChip(_ event: EKEvent) -> some View {
        Text(event.title ?? "Untitled")
            .font(.caption2)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(6)
    }
    
    @ViewBuilder
    private func taskChip(_ task: TodoItem) -> some View {
        Text(task.title)
            .font(.caption2)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.12))
            .foregroundStyle(.blue)
            .cornerRadius(6)
    }
}

/// Week timeline with hour rows and seven day columns.
private struct WeekTimelineView: View {
    let days: [Date]
    let events: [Date: [EKEvent]]
    let tasks: [Date: [TodoItem]]
    
    var body: some View {
        GeometryReader { proxy in
            let availableHeight = proxy.size.height
            let headerHeight: CGFloat = 28
            let rowHeight: CGFloat = 32 // label + padding
            let dividerHeight: CGFloat = 1
            let contentHeight = headerHeight + (rowHeight + dividerHeight) * 24 + 8 // padding
            let content = timelineContent
            
            if contentHeight > availableHeight {
                ScrollView { content }
            } else {
                content
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            Text("")
                .frame(width: 44)
            ForEach(days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortDayString(day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dayNumberString(day))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, 4)
    }
    
    private func eventsForHour(day: Date, hour: Int) -> [EKEvent] {
        let calendar = Calendar.current
        let dayEvents = events[day] ?? []
        return dayEvents.filter {
            calendar.component(.hour, from: $0.startDate) == hour
        }
    }
    
    private func tasksForHour(day: Date, hour: Int) -> [TodoItem] {
        let calendar = Calendar.current
        let dayTasks = tasks[day] ?? []
        return dayTasks.filter {
            guard let due = $0.dueDate else { return false }
            return calendar.component(.hour, from: due) == hour
        }
    }
    
    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
    
    private func shortDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func dayNumberString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func eventChip(_ event: EKEvent) -> some View {
        Text(event.title ?? "Untitled")
            .font(.caption2)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(6)
    }
    
    @ViewBuilder
    private func taskChip(_ task: TodoItem) -> some View {
        Text(task.title)
            .font(.caption2)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.12))
            .foregroundStyle(.blue)
            .cornerRadius(6)
    }
    
    private var timelineContent: some View {
        LazyVStack(spacing: 0) {
            header
            Divider()
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(hourLabel(hour))
                        .font(.caption)
                        .frame(width: 44, alignment: .trailing)
                    
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 4) {
                            let hourEvents = eventsForHour(day: day, hour: hour)
                            let hourTasks = tasksForHour(day: day, hour: hour)
                            
                            if hourEvents.isEmpty && hourTasks.isEmpty {
                                Text(" ")
                                    .font(.caption2)
                            } else {
                                ForEach(hourEvents, id: \.eventIdentifier) { event in
                                    eventChip(event)
                                }
                                ForEach(hourTasks, id: \.id) { task in
                                    taskChip(task)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding(.vertical, 8)
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
