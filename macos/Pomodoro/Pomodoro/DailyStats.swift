//
//  DailyStats.swift
//  Pomodoro
//
//  Created by Zhengyang Hu on 1/15/26.
//

import Foundation

struct DailyStats: Equatable {
    private(set) var dayStart: Date
    private(set) var totalFocusSeconds: Int
    private(set) var totalBreakSeconds: Int
    private(set) var completedSessions: Int

    init(date: Date = Date(), calendar: Calendar = .current) {
        let startOfDay = calendar.startOfDay(for: date)
        self.dayStart = startOfDay
        self.totalFocusSeconds = 0
        self.totalBreakSeconds = 0
        self.completedSessions = 0
    }

    mutating func reset(for date: Date = Date(), calendar: Calendar = .current) {
        dayStart = calendar.startOfDay(for: date)
        totalFocusSeconds = 0
        totalBreakSeconds = 0
        completedSessions = 0
    }

    mutating func ensureCurrentDay(_ date: Date = Date(), calendar: Calendar = .current) {
        let startOfDay = calendar.startOfDay(for: date)
        guard startOfDay != dayStart else { return }
        reset(for: date, calendar: calendar)
    }

    mutating func logFocusSession(durationSeconds: Int, date: Date = Date(), calendar: Calendar = .current) {
        guard durationSeconds > 0 else { return }
        ensureCurrentDay(date, calendar: calendar)
        totalFocusSeconds += durationSeconds
        completedSessions += 1
    }

    mutating func logBreakSession(durationSeconds: Int, date: Date = Date(), calendar: Calendar = .current) {
        guard durationSeconds > 0 else { return }
        ensureCurrentDay(date, calendar: calendar)
        totalBreakSeconds += durationSeconds
    }
}
