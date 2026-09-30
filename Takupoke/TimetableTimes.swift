import Foundation

struct TimetableTimes: Codable, Equatable {
    struct Period: Codable, Equatable { let period: Int; let start: String; let end: String }
    struct Day: Codable, Equatable { let date: String; let periods: [Period] }
    let schemaVersion: Int
    let days: [Day]

    func validated() throws -> Self {
        guard schemaVersion == 1, days.count <= 400, Set(days.map(\.date)).count == days.count else {
            throw TimetableTimesError.invalidData
        }
        for day in days {
            guard SchoolDate(iso8601: day.date)?.iso8601 == day.date, day.periods.count == 8 else {
                throw TimetableTimesError.invalidData
            }
            var previousEnd = "00:00"
            for (index, slot) in day.periods.enumerated() {
                guard slot.period == index + 1, Self.validClock(slot.start), Self.validClock(slot.end),
                      slot.start < slot.end, slot.start >= previousEnd else { throw TimetableTimesError.invalidData }
                previousEnd = slot.end
            }
        }
        return self
    }

    func time(on date: SchoolDate, period: Int) -> String? {
        guard let slot = days.first(where: { $0.date == date.iso8601 })?.periods.first(where: { $0.period == period }) else { return nil }
        return "\(slot.start)〜\(slot.end)"
    }

    private static func validClock(_ value: String) -> Bool {
        guard value.utf8.count == 5 else { return false }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ $0.utf8.count == 2 && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return false }
        return hour < 24 && minute < 60
    }
}

enum TimetableTimesError: Error, LocalizedError {
    case invalidData, unavailable, storage, authentication, changed
    var errorDescription: String? {
        switch self {
        case .invalidData: return "授業時刻の形式を確認できませんでした。"
        case .unavailable: return "授業時刻を取得できませんでした。"
        case .storage: return "授業時刻を保存できませんでした。"
        case .authentication: return "認証を完了できませんでした。"
        case .changed: return "取得中に授業時刻が更新されました。もう一度お試しください。"
        }
    }
}

struct SavedTimetableTimes: Codable, Equatable {
    let revision: String
    let fetchedAt: Date
    let data: TimetableTimes
}
