import SwiftUI
import EventKit

/// Horizontal week view with selectable day columns.
struct WeekCalendarView: View {
    let days: [Date]
    let events: [EKEvent]
    let tasks: [TodoItem]
    
    @State private var selectedDay: Date?
    
    private let columnSpacing: CGFloat = 10
    private let columnWidth: CGFloat = 180
    
    var body: some View {
        // Outer vertical scroll prevents bottom clipping when content grows tall.
        ScrollView {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    ForEach(days, id: \.self) { day in
                        let dayEvents = eventsForDay(day)
                        let dayTasks = tasksForDay(day)
                        DayColumnView(
                            date: day,
                            events: dayEvents,
                            tasks: dayTasks,
                            isSelected: isSameDay(day, selectedDay),
                            onSelect: { selectedDay = day }
                        )
                        .frame(minWidth: columnWidth, maxWidth: columnWidth, alignment: .topLeading)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedDay == nil {
                selectedDay = days.first
            }
        }
    }
    
    private func eventsForDay(_ day: Date) -> [EKEvent] {
        let cal = Calendar.current
        return events
            .filter { cal.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private func tasksForDay(_ day: Date) -> [TodoItem] {
        let cal = Calendar.current
        return tasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return cal.isDate(due, inSameDayAs: day)
            }
            .sorted { lhs, rhs in
                guard let l = lhs.dueDate, let r = rhs.dueDate else { return false }
                return l < r
            }
    }
    
    private func isSameDay(_ lhs: Date, _ rhs: Date?) -> Bool {
        guard let rhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}

private struct DayColumnView: View {
    let date: Date
    let events: [EKEvent]
    let tasks: [TodoItem]
    let isSelected: Bool
    let onSelect: () -> Void
    
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df
    }()
    
    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dayFormatter.string(from: date))
                        .font(.subheadline)
                    Text(dayNumberString(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            if events.isEmpty && tasks.isEmpty {
                Text("No events")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events, id: \.eventIdentifier) { event in
                        EventCard(event: event)
                    }
                    ForEach(tasks, id: \.id) { task in
                        TaskCard(task: task)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.035))
    }
    
    private func dayNumberString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df.string(from: date)
    }
    
    private struct EventCard: View {
        let event: EKEvent
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(timeRange(event))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(cgColor: event.calendar.cgColor).opacity(0.12))
            .cornerRadius(7)
        }
        
        private func timeRange(_ event: EKEvent) -> String {
            if event.isAllDay {
                return "All day"
            }
            let formatter = DayColumnView.timeFormatter
            return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
        }
    }
    
    private struct TaskCard: View {
        let task: TodoItem
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                if let due = task.dueDate {
                    Text(timeRange(from: due, duration: task.durationMinutes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No due time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(7)
        }
        
        private func timeRange(from start: Date, duration: Int?) -> String {
            let formatter = DayColumnView.timeFormatter
            let end = start.addingTimeInterval(Double((duration ?? 30) * 60))
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
    }
}
