import SwiftUI
import EventKit

/// Month view for the calendar showing a grid of days with events.
/// Displays a traditional calendar month layout with event indicators.
struct CalendarMonthView: View {
    let date: Date
    let events: [EKEvent]
    
    private let monthColumns: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 70), spacing: 8), count: 7)
    
    private static let weekdaySymbols: [String] = {
        let calendar = Calendar.current
        return calendar.shortStandaloneWeekdaySymbols
    }()
    
    var body: some View {
        let gridDays = monthGridDays(from: date)
        
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
    
    private func events(for day: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: day)
        }
    }
    
    @ViewBuilder
    private func monthCell(for day: Date?) -> some View {
        if let day {
            let calendar = Calendar.current
            let isToday = calendar.isDateInToday(day)
            let dayEvents = events(for: day)
            
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
}
