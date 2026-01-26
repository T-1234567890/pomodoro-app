import Foundation
import Combine

/// Local-only storage for focus session records.
/// No server sync or cloud dependency by design to keep insights private and predictable.
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
    let taskId: UUID?
    
    init(startTime: Date, endTime: Date, durationSeconds: Int, taskId: UUID?) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.taskId = taskId
    }
}

@MainActor
final class SessionRecordStore: ObservableObject {
    static let shared = SessionRecordStore()
    
    @Published private(set) var records: [SessionRecord] = []
    
    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = supportDir.appendingPathComponent("PomodoroApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("session_records.json")
        load()
    }
    
    func appendRecord(startTime: Date, endTime: Date, durationSeconds: Int, taskId: UUID?) {
        let record = SessionRecord(startTime: startTime, endTime: endTime, durationSeconds: durationSeconds, taskId: taskId)
        records.append(record)
        save()
    }
    
    /// Returns records within the last N days (inclusive of today).
    func records(lastDays: Int, calendar: Calendar = .current) -> [SessionRecord] {
        guard lastDays > 0 else { return [] }
        let start = calendar.date(byAdding: .day, value: -(lastDays - 1), to: calendar.startOfDay(for: Date())) ?? Date()
        return records.filter { $0.startTime >= start }
    }
    
    /// Returns records for a specific day.
    func records(for day: Date, calendar: Calendar = .current) -> [SessionRecord] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return records.filter { $0.startTime >= start && $0.startTime < end }
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? decoder.decode([SessionRecord].self, from: data) {
            records = decoded
        }
    }
    
    private func save() {
        if let data = try? encoder.encode(records) {
            try? data.write(to: fileURL)
        }
    }
}
