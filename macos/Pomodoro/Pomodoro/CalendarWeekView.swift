import SwiftUI
import EventKit

/// Week view for the calendar showing a 7-day grid with hour rows.
/// Each day column displays events positioned by their start time.
struct CalendarWeekView: View {
    let days: [Date]
    let events: [Date: [EKEvent]]
    
    // Height estimates for scroll calculation
    private let estimatedRowHeight: CGFloat = 32
    private let estimatedHeaderHeight: CGFloat = 28
    private let estimatedPadding: CGFloat = 16
    private let estimatedDividerHeight: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let contentHeight = calculateContentHeight()
            let needsScrolling = contentHeight > availableHeight
            
            if needsScrolling {
                ScrollView {
                    weekContent
                }
            } else {
                VStack(spacing: 0) {
                    weekContent
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }
    
    private var weekContent: some View {
        LazyVStack(spacing: 0) {
            header
            Divider()
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(hourLabel(hour))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                    
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 4) {
                            let hourEvents = eventsForHour(day: day, hour: hour)
                            
                            if hourEvents.isEmpty {
                                Text(" ")
                                    .font(.caption2)
                            } else {
                                ForEach(hourEvents, id: \.eventIdentifier) { event in
                                    eventChip(event)
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
    
    private func calculateContentHeight() -> CGFloat {
        let hourRowsCount: CGFloat = 24
        let dividersCount: CGFloat = 25 // 1 header divider + 24 hour dividers
        
        let totalHeight = estimatedHeaderHeight + 
                         (hourRowsCount * estimatedRowHeight) + 
                         (dividersCount * estimatedDividerHeight) + 
                         estimatedPadding
        
        return totalHeight + 10
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
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title ?? "Untitled")
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(cgColor: event.calendar.cgColor).opacity(0.15))
        .cornerRadius(4)
    }
}
